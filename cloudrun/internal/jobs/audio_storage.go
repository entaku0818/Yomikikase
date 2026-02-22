package jobs

import (
	"context"
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
