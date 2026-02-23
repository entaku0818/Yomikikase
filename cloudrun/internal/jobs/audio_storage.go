package jobs

import (
	"context"
	"encoding/binary"
	"fmt"
	"os"

	"cloud.google.com/go/storage"
)

// GCSAudioStorage implements AudioStorage using Google Cloud Storage.
type GCSAudioStorage struct {
	client     *storage.Client
	bucketName string
}

// NewGCSAudioStorage creates a GCSAudioStorage using STORAGE_BUCKET_NAME env var.
func NewGCSAudioStorage(client *storage.Client) *GCSAudioStorage {
	return &GCSAudioStorage{
		client:     client,
		bucketName: os.Getenv("STORAGE_BUCKET_NAME"),
	}
}

// UploadWAVStreaming streams PCM audio chunks to GCS without holding all data in
// memory. It:
//  1. Opens a GCS writer and streams all PCM bytes from fillPCM into a temp object.
//  2. Writes the 44-byte WAV header (with corrected size fields) to a second temp object.
//  3. Composes [header, pcm] → the final WAV object via GCS compose.
//  4. Sets a public-read ACL on the final object and deletes the temp objects.
//
// Peak memory is proportional to a single TTS chunk (~2–3 MB), not the whole book.
func (s *GCSAudioStorage) UploadWAVStreaming(
	ctx context.Context,
	filename string,
	fillPCM func(setHeader func([]byte), writePCM func([]byte)) error,
) (string, error) {
	if s.bucketName == "" {
		return "", fmt.Errorf("STORAGE_BUCKET_NAME not set")
	}
	bucket := s.client.Bucket(s.bucketName)

	// --- 1. Stream raw PCM data into a temp GCS object ---
	pcmName := filename + ".pcm.tmp"
	pcmObj := bucket.Object(pcmName)
	pw := pcmObj.NewWriter(ctx)
	pw.ContentType = "application/octet-stream"

	var pcmSize int64
	var firstHeader []byte

	setHeaderFn := func(h []byte) {
		if len(h) >= 44 {
			firstHeader = make([]byte, 44)
			copy(firstHeader, h[:44])
		}
	}
	writePCMFn := func(data []byte) {
		if len(data) > 0 {
			pw.Write(data) // nolint: errcheck – errors surfaced on pw.Close()
			pcmSize += int64(len(data))
		}
	}

	if err := fillPCM(setHeaderFn, writePCMFn); err != nil {
		pw.Close()
		bucket.Object(pcmName).Delete(ctx) // best-effort cleanup
		return "", err
	}
	if err := pw.Close(); err != nil {
		bucket.Object(pcmName).Delete(ctx)
		return "", fmt.Errorf("close PCM GCS writer: %w", err)
	}
	if firstHeader == nil {
		bucket.Object(pcmName).Delete(ctx)
		return "", fmt.Errorf("no audio data produced")
	}

	// --- 2. Build a correct 44-byte WAV header ---
	binary.LittleEndian.PutUint32(firstHeader[4:8], uint32(36+pcmSize))
	binary.LittleEndian.PutUint32(firstHeader[40:44], uint32(pcmSize))

	hdrName := filename + ".hdr.tmp"
	hdrObj := bucket.Object(hdrName)
	hw := hdrObj.NewWriter(ctx)
	hw.ContentType = "audio/wav" // compose inherits ContentType from first source
	if _, err := hw.Write(firstHeader); err != nil {
		hw.Close()
		bucket.Object(hdrName).Delete(ctx)
		bucket.Object(pcmName).Delete(ctx)
		return "", fmt.Errorf("write WAV header to GCS: %w", err)
	}
	if err := hw.Close(); err != nil {
		bucket.Object(hdrName).Delete(ctx)
		bucket.Object(pcmName).Delete(ctx)
		return "", fmt.Errorf("close header GCS writer: %w", err)
	}

	// --- 3. Compose [header, pcm] → final WAV object ---
	finalObj := bucket.Object(filename)
	if _, err := finalObj.ComposerFrom(hdrObj, pcmObj).Run(ctx); err != nil {
		bucket.Object(hdrName).Delete(ctx)
		bucket.Object(pcmName).Delete(ctx)
		return "", fmt.Errorf("GCS compose WAV: %w", err)
	}

	// --- 4. Set public-read ACL ---
	if err := finalObj.ACL().Set(ctx, storage.AllUsers, storage.RoleReader); err != nil {
		bucket.Object(hdrName).Delete(ctx)
		bucket.Object(pcmName).Delete(ctx)
		return "", fmt.Errorf("set public ACL on composed WAV: %w", err)
	}

	// Cleanup temp objects (best-effort; ignore errors)
	bucket.Object(hdrName).Delete(ctx)
	bucket.Object(pcmName).Delete(ctx)

	return fmt.Sprintf("https://storage.googleapis.com/%s/%s", s.bucketName, filename), nil
}

func (s *GCSAudioStorage) Upload(ctx context.Context, data []byte, filename string) (string, error) {
	if s.bucketName == "" {
		return "", fmt.Errorf("STORAGE_BUCKET_NAME not set")
	}

	obj := s.client.Bucket(s.bucketName).Object(filename)
	w := obj.NewWriter(ctx)
	w.ContentType = "audio/wav"

	if _, err := w.Write(data); err != nil {
		w.Close()
		return "", fmt.Errorf("write to GCS %s: %w", filename, err)
	}
	if err := w.Close(); err != nil {
		return "", fmt.Errorf("close GCS writer %s: %w", filename, err)
	}

	if err := obj.ACL().Set(ctx, storage.AllUsers, storage.RoleReader); err != nil {
		return "", fmt.Errorf("set public ACL %s: %w", filename, err)
	}

	return fmt.Sprintf("https://storage.googleapis.com/%s/%s", s.bucketName, filename), nil
}
