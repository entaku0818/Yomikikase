package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/entaku0818/voiceyourtext-cloudrun/internal/config"
	"github.com/entaku0818/voiceyourtext-cloudrun/internal/jobs"
)

// JobDeps holds all dependencies for job handlers.
type JobDeps struct {
	Store    jobs.JobStore
	Queue    jobs.TaskQueue
	Gen      jobs.TTSGenerator
	Storage  jobs.AudioStorage
	Notifier jobs.Notifier
}

// CreateJobRequest is the request body for POST /jobs.
type CreateJobRequest struct {
	Text        string `json:"text"`
	VoiceID     string `json:"voiceId"`
	Language    string `json:"language"`
	Style       string `json:"style"`
	FileID      string `json:"fileId"`
	DeviceToken string `json:"deviceToken"`
}

// CreateJobResponse is the response for POST /jobs.
type CreateJobResponse struct {
	JobID string `json:"jobId"`
}

// ProcessTaskRequest is the request body for POST /jobs/process (called by Cloud Tasks).
type ProcessTaskRequest struct {
	JobID string `json:"jobId"`
}

// CreateJobHandler handles POST /jobs.
// Creates a job in Firestore and enqueues it to Cloud Tasks.
func (d *JobDeps) CreateJobHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req CreateJobRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}

	if req.Text == "" {
		http.Error(w, `{"error":"text is required"}`, http.StatusBadRequest)
		return
	}
	if req.VoiceID == "" {
		req.VoiceID = "ja-jp-female-a"
	}
	if req.Language == "" {
		if v := config.GetVoiceByID(req.VoiceID); v != nil {
			req.Language = v.Language
		}
	}

	job := &jobs.Job{
		ID:          uuid.New().String(),
		Status:      jobs.JobStatusPending,
		Text:        req.Text,
		VoiceID:     req.VoiceID,
		Language:    req.Language,
		Style:       req.Style,
		FileID:      req.FileID,
		DeviceToken: req.DeviceToken,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	ctx := r.Context()
	if err := d.Store.Create(ctx, job); err != nil {
		log.Printf("CreateJob: store.Create failed: %v", err)
		http.Error(w, `{"error":"failed to create job"}`, http.StatusInternalServerError)
		return
	}

	if err := d.Queue.Enqueue(ctx, job.ID); err != nil {
		// Log but don't fail: job is persisted, can be retried
		log.Printf("CreateJob: queue.Enqueue %s failed: %v", job.ID, err)
	}

	log.Printf("CreateJob: created jobId=%s text_len=%d voiceId=%s", job.ID, len(job.Text), job.VoiceID)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusAccepted)
	json.NewEncoder(w).Encode(CreateJobResponse{JobID: job.ID})
}

// GetJobHandler handles GET /jobs/{jobId}.
// Returns the current state of the job including audioUrl and timepoints on completion.
func (d *JobDeps) GetJobHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	jobID := strings.TrimPrefix(r.URL.Path, "/jobs/")
	if jobID == "" || jobID == "process" {
		http.Error(w, `{"error":"jobId required"}`, http.StatusBadRequest)
		return
	}

	job, err := d.Store.Get(r.Context(), jobID)
	if err != nil {
		log.Printf("GetJob: store.Get %s: %v", jobID, err)
		http.Error(w, `{"error":"job not found"}`, http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(job)
}

// ProcessJobHandler handles POST /jobs/process.
// Called by Cloud Tasks; processes the job asynchronously.
// Always returns 200 so Cloud Tasks does not retry on application errors.
func (d *JobDeps) ProcessJobHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req ProcessTaskRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}
	if req.JobID == "" {
		http.Error(w, `{"error":"jobId required"}`, http.StatusBadRequest)
		return
	}

	ctx := r.Context()

	job, err := d.Store.Get(ctx, req.JobID)
	if err != nil {
		// Job not found — return 200 to prevent Cloud Tasks from retrying
		log.Printf("ProcessJob: get job %s: %v", req.JobID, err)
		w.WriteHeader(http.StatusOK)
		return
	}

	if err := d.Store.SetProcessing(ctx, job.ID); err != nil {
		log.Printf("ProcessJob: set processing %s: %v", job.ID, err)
	}

	voice := config.GetVoiceByID(job.VoiceID)
	if voice == nil {
		errMsg := fmt.Sprintf("unknown voiceId: %s", job.VoiceID)
		log.Printf("ProcessJob: %s", errMsg)
		d.failJob(ctx, job, errMsg)
		w.WriteHeader(http.StatusOK)
		return
	}

	result, err := jobs.ProcessJob(ctx, job, voice, d.Gen, d.Storage)
	if err != nil {
		log.Printf("ProcessJob: process %s failed: %v", job.ID, err)
		d.failJob(ctx, job, err.Error())
		w.WriteHeader(http.StatusOK)
		return
	}

	if err := d.Store.SetCompleted(ctx, job.ID, result.AudioURL, result.Timepoints); err != nil {
		log.Printf("ProcessJob: set completed %s: %v", job.ID, err)
	}

	d.notifyCompleted(ctx, job, result)
	log.Printf("ProcessJob: completed jobId=%s audioUrl=%s", job.ID, result.AudioURL)
	w.WriteHeader(http.StatusOK)
}

func (d *JobDeps) failJob(ctx context.Context, job *jobs.Job, errMsg string) {
	if err := d.Store.SetFailed(ctx, job.ID, errMsg); err != nil {
		log.Printf("failJob: set failed %s: %v", job.ID, err)
	}
	d.notifyFailed(ctx, job, errMsg)
}

func (d *JobDeps) notifyCompleted(ctx context.Context, job *jobs.Job, result *jobs.ProcessResult) {
	if job.DeviceToken == "" || d.Notifier == nil {
		return
	}
	data := map[string]string{
		"jobId":    job.ID,
		"audioUrl": result.AudioURL,
		"fileId":   job.FileID,
		"status":   string(jobs.JobStatusCompleted),
	}
	if err := d.Notifier.Send(ctx, job.DeviceToken, "音声生成完了", "テキストの読み上げ音声が生成されました", data); err != nil {
		log.Printf("notifyCompleted: FCM %s: %v", job.ID, err)
	}
}

func (d *JobDeps) notifyFailed(ctx context.Context, job *jobs.Job, errMsg string) {
	if job.DeviceToken == "" || d.Notifier == nil {
		return
	}
	data := map[string]string{
		"jobId":  job.ID,
		"fileId": job.FileID,
		"status": string(jobs.JobStatusFailed),
		"error":  errMsg,
	}
	if err := d.Notifier.Send(ctx, job.DeviceToken, "音声生成失敗", "音声の生成に失敗しました", data); err != nil {
		log.Printf("notifyFailed: FCM %s: %v", job.ID, err)
	}
}
