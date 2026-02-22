package wav

import (
	"encoding/binary"
	"fmt"
)

// Duration returns the playback duration of a WAV file in seconds by parsing
// the PCM header fields. Returns 0 if the data is too short or invalid.
func Duration(data []byte) float64 {
	if len(data) < 44 {
		return 0
	}
	sampleRate    := binary.LittleEndian.Uint32(data[24:28])
	dataSize      := binary.LittleEndian.Uint32(data[40:44])
	bitsPerSample := binary.LittleEndian.Uint16(data[34:36])
	numChannels   := binary.LittleEndian.Uint16(data[22:24])
	if sampleRate == 0 || bitsPerSample == 0 || numChannels == 0 {
		return 0
	}
	bytesPerSample := int(bitsPerSample/8) * int(numChannels)
	if bytesPerSample == 0 {
		return 0
	}
	return float64(int(dataSize)/bytesPerSample) / float64(sampleRate)
}

// Concatenate merges multiple PCM-WAV files into one.
// The RIFF header of the first file is reused; only PCM data (after byte 44)
// from all files is concatenated, and the RIFF/data sizes are updated.
func Concatenate(files [][]byte) ([]byte, error) {
	if len(files) == 0 {
		return nil, fmt.Errorf("wav: no files to concatenate")
	}
	if len(files) == 1 {
		return files[0], nil
	}
	if len(files[0]) < 44 {
		return nil, fmt.Errorf("wav: first file has invalid header (len=%d)", len(files[0]))
	}

	var pcm []byte
	for _, f := range files {
		if len(f) > 44 {
			pcm = append(pcm, f[44:]...)
		}
	}

	result := make([]byte, 44+len(pcm))
	copy(result[:44], files[0][:44])
	copy(result[44:], pcm)

	binary.LittleEndian.PutUint32(result[4:8], uint32(36+len(pcm)))
	binary.LittleEndian.PutUint32(result[40:44], uint32(len(pcm)))

	return result, nil
}
