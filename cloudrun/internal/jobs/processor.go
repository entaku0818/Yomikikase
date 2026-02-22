package jobs

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	"github.com/entaku0818/voiceyourtext-cloudrun/internal/config"
	"github.com/entaku0818/voiceyourtext-cloudrun/internal/wav"
	"github.com/google/uuid"
)

// MaxChunkBytes is the maximum UTF-8 byte size per TTS API request.
// The server validates len(text) <= 5000 (bytes); we use 4500 for safety.
const MaxChunkBytes = 4500

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

// ProcessJob splits job.Text into chunks, generates TTS for each chunk,
// concatenates the resulting WAV files, adjusts timepoints, and uploads
// the final audio. All external I/O is injected via interfaces.
func ProcessJob(
	ctx context.Context,
	job *Job,
	voice *config.VoiceOption,
	gen TTSGenerator,
	storage AudioStorage,
) (*ProcessResult, error) {
	chunks := SplitText(job.Text, MaxChunkBytes)

	var wavFiles [][]byte
	var allTimepoints []TTSTimepoint
	var cumulativeTime float64

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

	filename := fmt.Sprintf("audio/jobs/%s_%s.wav", job.VoiceID, uuid.New().String())
	audioURL, err := storage.Upload(ctx, combined, filename)
	if err != nil {
		return nil, fmt.Errorf("audio upload failed: %w", err)
	}

	return &ProcessResult{
		AudioURL:   audioURL,
		Timepoints: allTimepoints,
	}, nil
}
