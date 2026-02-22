package jobs_test

import (
	"context"
	"encoding/binary"
	"fmt"
	"math"
	"strings"
	"testing"

	"github.com/entaku0818/voiceyourtext-cloudrun/internal/config"
	"github.com/entaku0818/voiceyourtext-cloudrun/internal/jobs"
)

// --- helpers ---

func makeWAV(sampleRate uint32, channels, bitsPerSample uint16, numSamples int) []byte {
	pcmSize := numSamples * int(channels) * int(bitsPerSample/8)
	data := make([]byte, 44+pcmSize)
	copy(data[0:4], "RIFF")
	binary.LittleEndian.PutUint32(data[4:8], uint32(36+pcmSize))
	copy(data[8:12], "WAVE")
	copy(data[12:16], "fmt ")
	binary.LittleEndian.PutUint32(data[16:20], 16)
	binary.LittleEndian.PutUint16(data[20:22], 1)
	binary.LittleEndian.PutUint16(data[22:24], channels)
	binary.LittleEndian.PutUint32(data[24:28], sampleRate)
	binary.LittleEndian.PutUint32(data[28:32], sampleRate*uint32(channels)*uint32(bitsPerSample/8))
	binary.LittleEndian.PutUint16(data[32:34], channels*bitsPerSample/8)
	binary.LittleEndian.PutUint16(data[34:36], bitsPerSample)
	copy(data[36:40], "data")
	binary.LittleEndian.PutUint32(data[40:44], uint32(pcmSize))
	return data
}

// mockTTSGenerator returns a 1-second WAV and one timepoint per call.
type mockTTSGenerator struct {
	callCount int
	failAt    int // fail on the n-th call (0 = never fail)
}

func (m *mockTTSGenerator) Generate(_ context.Context, text string, _ *config.VoiceOption, _ string) ([]byte, []jobs.TTSTimepoint, error) {
	m.callCount++
	if m.failAt > 0 && m.callCount == m.failAt {
		return nil, nil, fmt.Errorf("mock TTS error")
	}
	audio := makeWAV(16000, 1, 16, 16000) // 1 second of silence
	tps := []jobs.TTSTimepoint{
		{MarkName: "0:0:3", TimeSeconds: 0.1},
	}
	return audio, tps, nil
}

// mockAudioStorage records the last uploaded data.
type mockAudioStorage struct {
	uploadedData []byte
	uploadedName string
}

func (m *mockAudioStorage) Upload(_ context.Context, data []byte, filename string) (string, error) {
	m.uploadedData = data
	m.uploadedName = filename
	return "https://storage.example.com/" + filename, nil
}

// --- SplitText ---

func TestSplitText_ShortText(t *testing.T) {
	chunks := jobs.SplitText("hello", 4500)
	if len(chunks) != 1 {
		t.Fatalf("expected 1 chunk, got %d", len(chunks))
	}
	if chunks[0].Text != "hello" || chunks[0].CharOffset != 0 {
		t.Errorf("unexpected chunk: %+v", chunks[0])
	}
}

func TestSplitText_JapaneseExceedsBytes(t *testing.T) {
	// "あ" = 3 UTF-8 bytes. 2000 chars = 6000 bytes > 4500 → must split.
	text := strings.Repeat("あ", 2000)
	chunks := jobs.SplitText(text, 4500)
	if len(chunks) < 2 {
		t.Fatalf("expected multiple chunks, got %d", len(chunks))
	}
	for _, c := range chunks {
		byteLen := len([]byte(c.Text))
		if byteLen > 4500 {
			t.Errorf("chunk exceeded maxBytes: %d bytes", byteLen)
		}
	}
}

func TestSplitText_SentenceBoundary(t *testing.T) {
	// Build a text that straddles the boundary, with a '。' near the split point
	sentence := strings.Repeat("あ", 100) + "。"
	text := strings.Repeat(sentence, 20) // ~6000 bytes
	chunks := jobs.SplitText(text, 4500)
	for _, c := range chunks {
		if len([]byte(c.Text)) > 4500 {
			t.Errorf("chunk exceeded maxBytes: %d bytes", len([]byte(c.Text)))
		}
	}
}

func TestSplitText_ReconstructsOriginal(t *testing.T) {
	text := strings.Repeat("日本語のテキスト。", 300) // many sentences
	chunks := jobs.SplitText(text, 4500)
	var reconstructed strings.Builder
	for _, c := range chunks {
		reconstructed.WriteString(c.Text)
	}
	if reconstructed.String() != text {
		t.Error("reconstructed text does not match original")
	}
}

func TestSplitText_OffsetMonotonicallyIncreases(t *testing.T) {
	text := strings.Repeat("あいうえお。", 300)
	chunks := jobs.SplitText(text, 4500)
	for i := 1; i < len(chunks); i++ {
		if chunks[i].CharOffset <= chunks[i-1].CharOffset {
			t.Errorf("offsets not increasing: chunk[%d].offset=%d, chunk[%d].offset=%d",
				i-1, chunks[i-1].CharOffset, i, chunks[i].CharOffset)
		}
	}
}

// --- AdjustTimepoints ---

func TestAdjustTimepoints_Basic(t *testing.T) {
	tps := []jobs.TTSTimepoint{
		{MarkName: "0:10:15", TimeSeconds: 0.5},
		{MarkName: "1:20:25", TimeSeconds: 1.0},
	}
	adjusted := jobs.AdjustTimepoints(tps, 100, 2.0)
	if len(adjusted) != 2 {
		t.Fatalf("expected 2 timepoints, got %d", len(adjusted))
	}
	if adjusted[0].MarkName != "0:110:115" {
		t.Errorf("unexpected markName: %s", adjusted[0].MarkName)
	}
	if math.Abs(adjusted[0].TimeSeconds-2.5) > 0.001 {
		t.Errorf("unexpected timeSeconds: %f", adjusted[0].TimeSeconds)
	}
	if adjusted[1].MarkName != "1:120:125" {
		t.Errorf("unexpected markName: %s", adjusted[1].MarkName)
	}
}

func TestAdjustTimepoints_ZeroOffset(t *testing.T) {
	tps := []jobs.TTSTimepoint{{MarkName: "0:5:10", TimeSeconds: 0.3}}
	adjusted := jobs.AdjustTimepoints(tps, 0, 0)
	if adjusted[0].MarkName != "0:5:10" || math.Abs(adjusted[0].TimeSeconds-0.3) > 0.001 {
		t.Errorf("zero offset should not change values: %+v", adjusted[0])
	}
}

func TestAdjustTimepoints_InvalidMarkName(t *testing.T) {
	tps := []jobs.TTSTimepoint{
		{MarkName: "invalid", TimeSeconds: 0.1},
		{MarkName: "0:5:10", TimeSeconds: 0.2},
	}
	adjusted := jobs.AdjustTimepoints(tps, 0, 0)
	// Invalid entry should be skipped
	if len(adjusted) != 1 {
		t.Errorf("expected 1 valid timepoint, got %d", len(adjusted))
	}
}

// --- ProcessJob ---

func TestProcessJob_SingleChunk(t *testing.T) {
	gen := &mockTTSGenerator{}
	store := &mockAudioStorage{}
	voice := &config.VoiceOption{ID: "ja-jp-female-a", Language: "ja-JP", WavenetVoice: "ja-JP-Wavenet-A"}

	job := &jobs.Job{
		ID:       "test-job-1",
		Text:     "短いテキスト",
		VoiceID:  "ja-jp-female-a",
		Language: "ja-JP",
	}

	result, err := jobs.ProcessJob(context.Background(), job, voice, gen, store)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if gen.callCount != 1 {
		t.Errorf("expected 1 TTS call, got %d", gen.callCount)
	}
	if result.AudioURL == "" {
		t.Error("expected non-empty AudioURL")
	}
}

func TestProcessJob_MultipleChunks(t *testing.T) {
	gen := &mockTTSGenerator{}
	store := &mockAudioStorage{}
	voice := &config.VoiceOption{ID: "ja-jp-female-a", Language: "ja-JP", WavenetVoice: "ja-JP-Wavenet-A"}

	// 2000 Japanese chars = 6000 bytes → at least 2 chunks
	job := &jobs.Job{
		ID:       "test-job-2",
		Text:     strings.Repeat("あいうえお。", 400),
		VoiceID:  "ja-jp-female-a",
		Language: "ja-JP",
	}

	result, err := jobs.ProcessJob(context.Background(), job, voice, gen, store)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if gen.callCount < 2 {
		t.Errorf("expected multiple TTS calls for long text, got %d", gen.callCount)
	}
	if len(result.Timepoints) == 0 {
		t.Error("expected timepoints to be present")
	}
	// Timepoints from later chunks should have larger timeSeconds
	for i := 1; i < len(result.Timepoints); i++ {
		if result.Timepoints[i].TimeSeconds < result.Timepoints[i-1].TimeSeconds {
			t.Errorf("timepoints not monotonically increasing at index %d", i)
		}
	}
}

func TestProcessJob_TTSError(t *testing.T) {
	gen := &mockTTSGenerator{failAt: 2} // fail on second chunk
	store := &mockAudioStorage{}
	voice := &config.VoiceOption{ID: "ja-jp-female-a", Language: "ja-JP", WavenetVoice: "ja-JP-Wavenet-A"}

	job := &jobs.Job{
		ID:      "test-job-3",
		Text:    strings.Repeat("あいうえお。", 400),
		VoiceID: "ja-jp-female-a",
	}

	_, err := jobs.ProcessJob(context.Background(), job, voice, gen, store)
	if err == nil {
		t.Error("expected error when TTS fails")
	}
}
