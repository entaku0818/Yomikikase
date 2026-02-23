package jobs

import (
	"context"
	"time"

	"github.com/entaku0818/voiceyourtext-cloudrun/internal/config"
)

// JobStatus represents the lifecycle state of a TTS generation job.
type JobStatus string

const (
	JobStatusPending    JobStatus = "pending"
	JobStatusProcessing JobStatus = "processing"
	JobStatusCompleted  JobStatus = "completed"
	JobStatusFailed     JobStatus = "failed"
)

// Job holds the request parameters and current state of a TTS generation job.
type Job struct {
	ID          string         `firestore:"id"          json:"id"`
	Status      JobStatus      `firestore:"status"      json:"status"`
	Text        string         `firestore:"text"        json:"text"`
	VoiceID     string         `firestore:"voiceId"     json:"voiceId"`
	Language    string         `firestore:"language"    json:"language"`
	Style       string         `firestore:"style"       json:"style"`
	FileID      string         `firestore:"fileId"      json:"fileId"`
	DeviceToken string         `firestore:"deviceToken" json:"-"` // never expose token in API response
	AudioURL    string         `firestore:"audioUrl,omitempty"   json:"audioUrl,omitempty"`
	Timepoints  []TTSTimepoint `firestore:"timepoints,omitempty" json:"timepoints,omitempty"`
	ErrorMsg    string         `firestore:"errorMsg,omitempty"   json:"errorMsg,omitempty"`
	CreatedAt   time.Time      `firestore:"createdAt"   json:"createdAt"`
	UpdatedAt   time.Time      `firestore:"updatedAt"   json:"updatedAt"`
}

// TTSTimepoint mirrors the iOS model: markName encodes char indices as
// "index:startChar:endChar" and timeSeconds is seconds from audio start.
type TTSTimepoint struct {
	MarkName    string  `json:"markName"`
	TimeSeconds float64 `json:"timeSeconds"`
}

// --- Interfaces (all external dependencies are behind interfaces for testability) ---

// JobStore persists and retrieves Job documents.
type JobStore interface {
	Create(ctx context.Context, job *Job) error
	Get(ctx context.Context, jobID string) (*Job, error)
	SetProcessing(ctx context.Context, jobID string) error
	SetCompleted(ctx context.Context, jobID, audioURL string, timepoints []TTSTimepoint) error
	SetFailed(ctx context.Context, jobID, errMsg string) error
}

// TaskQueue enqueues a job ID for asynchronous processing.
type TaskQueue interface {
	Enqueue(ctx context.Context, jobID string) error
}

// Notifier sends push notifications to a device.
type Notifier interface {
	Send(ctx context.Context, deviceToken, title, body string, data map[string]string) error
}

// TTSGenerator generates audio and returns raw WAV bytes plus timepoints.
type TTSGenerator interface {
	Generate(ctx context.Context, text string, voice *config.VoiceOption, language string) (audioWAV []byte, timepoints []TTSTimepoint, err error)
}

// AudioStorage stores a WAV file and returns its public URL.
type AudioStorage interface {
	Upload(ctx context.Context, data []byte, filename string) (audioURL string, err error)
}
