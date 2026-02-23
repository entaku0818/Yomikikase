package jobs

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/entaku0818/voiceyourtext-cloudrun/internal/config"
	"github.com/entaku0818/voiceyourtext-cloudrun/internal/wav"
	"github.com/google/uuid"
)

// MaxChunkBytes is the maximum UTF-8 byte size per TTS API request.
// Google TTS SSML limit is 5000 chars including tags. Each byte of text
// generates ~2-3 chars of SSML overhead (mark tags), so 1000 bytes ≈ 3000 SSML chars.
const MaxChunkBytes = 1000

// TextChunk is a slice of the original text with its character offset.
type TextChunk struct {
	Text       string
	CharOffset int // rune (character) offset into the original text
}

// SplitText splits text into chunks of at most maxBytes UTF-8 bytes.
// It searches backwards within the last 20% of each chunk for a natural
// sentence boundary (。.!?！？\n) to avoid splitting mid-sentence.
func SplitText(text string, maxBytes int) []TextChunk {
	if len([]byte(text)) <= maxBytes {
		return []TextChunk{{Text: text, CharOffset: 0}}
	}

	runes := []rune(text)
	var chunks []TextChunk
	startRune := 0

	for startRune < len(runes) {
		// Count how many runes fit within maxBytes
		byteCount := 0
		endRune := startRune
		for endRune < len(runes) {
			runeBytes := len(string(runes[endRune]))
			if byteCount+runeBytes > maxBytes {
				break
			}
			byteCount += runeBytes
			endRune++
		}

		// Edge case: a single rune exceeds maxBytes (shouldn't happen with normal text)
		if endRune == startRune {
			endRune = startRune + 1
		}

		// Search backwards for a sentence boundary within the last 20% of the chunk
		minBoundary := startRune + (endRune-startRune)*4/5
		splitRune := endRune
		for i := endRune - 1; i > minBoundary; i-- {
			switch runes[i] {
			case '\n', '。', '.', '!', '?', '！', '？':
				splitRune = i + 1
				goto foundBoundary
			}
		}
	foundBoundary:

		chunks = append(chunks, TextChunk{
			Text:       string(runes[startRune:splitRune]),
			CharOffset: startRune,
		})
		startRune = splitRune
	}

	return chunks
}

// AdjustTimepoints offsets timepoint character indices by charOffset and
// time values by timeOffset so they align with the full original text and audio.
func AdjustTimepoints(tps []TTSTimepoint, charOffset int, timeOffset float64) []TTSTimepoint {
	result := make([]TTSTimepoint, 0, len(tps))
	for _, tp := range tps {
		parts := strings.Split(tp.MarkName, ":")
		if len(parts) != 3 {
			continue
		}
		idx, err1 := strconv.Atoi(parts[0])
		start, err2 := strconv.Atoi(parts[1])
		end, err3 := strconv.Atoi(parts[2])
		if err1 != nil || err2 != nil || err3 != nil {
			continue
		}
		result = append(result, TTSTimepoint{
			MarkName:    fmt.Sprintf("%d:%d:%d", idx, start+charOffset, end+charOffset),
			TimeSeconds: tp.TimeSeconds + timeOffset,
		})
	}
	return result
}

// ProcessResult holds the output of a completed job.
type ProcessResult struct {
	AudioURL   string
	Timepoints []TTSTimepoint
}

// downloadText fetches text from a URL (used when text is stored in GCS).
func downloadText(ctx context.Context, url string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("http get: %w", err)
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("read body: %w", err)
	}
	return string(data), nil
}

// ProcessJob splits job.Text into chunks, generates TTS for each chunk,
// concatenates the resulting WAV files, adjusts timepoints, and uploads
// the final audio. All external I/O is injected via interfaces.
//
// When storage implements StreamingAudioStorage, PCM data is streamed directly
// to GCS one chunk at a time (constant memory usage regardless of text length).
// Otherwise it falls back to accumulating all chunks in memory before upload.
func ProcessJob(
	ctx context.Context,
	job *Job,
	voice *config.VoiceOption,
	gen TTSGenerator,
	storage AudioStorage,
) (*ProcessResult, error) {
	text := job.Text
	if text == "" && job.TextURL != "" {
		downloaded, err := downloadText(ctx, job.TextURL)
		if err != nil {
			return nil, fmt.Errorf("download text from GCS: %w", err)
		}
		text = downloaded
	}
	chunks := SplitText(text, MaxChunkBytes)

	filename := fmt.Sprintf("audio/jobs/%s_%s.wav", job.VoiceID, uuid.New().String())

	var allTimepoints []TTSTimepoint
	var cumulativeTime float64

	// Prefer streaming upload to avoid OOM on large texts.
	if streamer, ok := storage.(StreamingAudioStorage); ok {
		audioURL, err := streamer.UploadWAVStreaming(ctx, filename, func(setHeader func([]byte), writePCM func([]byte)) error {
			headerSet := false
			for _, chunk := range chunks {
				audioData, tps, err := gen.Generate(ctx, chunk.Text, voice, job.Language)
				if err != nil {
					return fmt.Errorf("TTS generation failed at offset %d: %w", chunk.CharOffset, err)
				}
				if !headerSet && len(audioData) >= 44 {
					setHeader(audioData[:44])
					headerSet = true
				}
				allTimepoints = append(allTimepoints, AdjustTimepoints(tps, chunk.CharOffset, cumulativeTime)...)
				cumulativeTime += wav.Duration(audioData)
				if len(audioData) > 44 {
					writePCM(audioData[44:])
				}
			}
			return nil
		})
		if err != nil {
			return nil, fmt.Errorf("streaming WAV upload failed: %w", err)
		}
		return &ProcessResult{AudioURL: audioURL, Timepoints: allTimepoints}, nil
	}

	// Fallback: accumulate all WAV data in memory (used in unit tests with mock storage).
	var wavFiles [][]byte
	for _, chunk := range chunks {
		audioData, tps, err := gen.Generate(ctx, chunk.Text, voice, job.Language)
		if err != nil {
			return nil, fmt.Errorf("TTS generation failed at offset %d: %w", chunk.CharOffset, err)
		}
		wavFiles = append(wavFiles, audioData)
		allTimepoints = append(allTimepoints, AdjustTimepoints(tps, chunk.CharOffset, cumulativeTime)...)
		cumulativeTime += wav.Duration(audioData)
	}

	combined, err := wav.Concatenate(wavFiles)
	if err != nil {
		return nil, fmt.Errorf("WAV concatenation failed: %w", err)
	}

	audioURL, err := storage.Upload(ctx, combined, filename)
	if err != nil {
		return nil, fmt.Errorf("audio upload failed: %w", err)
	}

	return &ProcessResult{
		AudioURL:   audioURL,
		Timepoints: allTimepoints,
	}, nil
}
