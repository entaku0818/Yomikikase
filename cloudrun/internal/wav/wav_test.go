package wav_test

import (
	"encoding/binary"
	"math"
	"testing"

	"github.com/entaku0818/voiceyourtext-cloudrun/internal/wav"
)

// makeWAV builds a minimal valid PCM WAV with the given params and numSamples of silence.
func makeWAV(sampleRate uint32, channels, bitsPerSample uint16, numSamples int) []byte {
	pcmSize := numSamples * int(channels) * int(bitsPerSample/8)
	data := make([]byte, 44+pcmSize)

	copy(data[0:4], "RIFF")
	binary.LittleEndian.PutUint32(data[4:8], uint32(36+pcmSize))
	copy(data[8:12], "WAVE")
	copy(data[12:16], "fmt ")
	binary.LittleEndian.PutUint32(data[16:20], 16)
	binary.LittleEndian.PutUint16(data[20:22], 1) // PCM
	binary.LittleEndian.PutUint16(data[22:24], channels)
	binary.LittleEndian.PutUint32(data[24:28], sampleRate)
	binary.LittleEndian.PutUint32(data[28:32], sampleRate*uint32(channels)*uint32(bitsPerSample/8))
	binary.LittleEndian.PutUint16(data[32:34], channels*bitsPerSample/8)
	binary.LittleEndian.PutUint16(data[34:36], bitsPerSample)
	copy(data[36:40], "data")
	binary.LittleEndian.PutUint32(data[40:44], uint32(pcmSize))
	return data
}

// --- Duration ---

func TestDuration_ValidMono16bit(t *testing.T) {
	// 44100 Hz, mono, 16-bit, 44100 samples → 1 second
	d := wav.Duration(makeWAV(44100, 1, 16, 44100))
	if math.Abs(d-1.0) > 0.001 {
		t.Errorf("expected ~1.0s, got %f", d)
	}
}

func TestDuration_ValidStereo(t *testing.T) {
	// 22050 Hz, stereo, 16-bit, 22050 samples → 1 second
	d := wav.Duration(makeWAV(22050, 2, 16, 22050))
	if math.Abs(d-1.0) > 0.001 {
		t.Errorf("expected ~1.0s, got %f", d)
	}
}

func TestDuration_TooShort(t *testing.T) {
	if wav.Duration([]byte{0, 1, 2}) != 0 {
		t.Error("expected 0 for short data")
	}
}

func TestDuration_Empty(t *testing.T) {
	if wav.Duration(nil) != 0 {
		t.Error("expected 0 for nil")
	}
}

// --- Concatenate ---

func TestConcatenate_SingleFile(t *testing.T) {
	w := makeWAV(44100, 1, 16, 100)
	result, err := wav.Concatenate([][]byte{w})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(result) != len(w) {
		t.Errorf("single-file concat changed size: got %d, want %d", len(result), len(w))
	}
}

func TestConcatenate_TwoFiles(t *testing.T) {
	w1 := makeWAV(44100, 1, 16, 44100) // 1 second
	w2 := makeWAV(44100, 1, 16, 44100) // 1 second

	result, err := wav.Concatenate([][]byte{w1, w2})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Should be ~2 seconds
	d := wav.Duration(result)
	if math.Abs(d-2.0) > 0.001 {
		t.Errorf("expected ~2.0s, got %f", d)
	}

	// RIFF size check: 36 + 2 * pcmOf1sec
	pcmOf1Sec := 44100 * 1 * 2 // samples * channels * bytesPerSample
	expectedRIFF := uint32(36 + 2*pcmOf1Sec)
	gotRIFF := binary.LittleEndian.Uint32(result[4:8])
	if gotRIFF != expectedRIFF {
		t.Errorf("RIFF size: got %d, want %d", gotRIFF, expectedRIFF)
	}
}

func TestConcatenate_ThreeFiles(t *testing.T) {
	files := [][]byte{
		makeWAV(16000, 1, 16, 16000), // 1s
		makeWAV(16000, 1, 16, 16000), // 1s
		makeWAV(16000, 1, 16, 16000), // 1s
	}
	result, err := wav.Concatenate(files)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	d := wav.Duration(result)
	if math.Abs(d-3.0) > 0.001 {
		t.Errorf("expected ~3.0s, got %f", d)
	}
}

func TestConcatenate_EmptySlice(t *testing.T) {
	_, err := wav.Concatenate(nil)
	if err == nil {
		t.Error("expected error for empty slice")
	}
}

func TestConcatenate_InvalidFirstHeader(t *testing.T) {
	_, err := wav.Concatenate([][]byte{{0, 1, 2}})
	// Single file with short data — returns as-is without error
	if err != nil {
		t.Errorf("single short file should be returned as-is, got error: %v", err)
	}
}
