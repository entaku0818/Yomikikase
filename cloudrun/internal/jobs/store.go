package jobs

import (
	"context"
	"fmt"
	"time"

	"cloud.google.com/go/firestore"
)

const jobsCollection = "ttsJobs"

// FirestoreJobStore is the Firestore-backed implementation of JobStore.
type FirestoreJobStore struct {
	client *firestore.Client
}

// NewFirestoreJobStore creates a new FirestoreJobStore.
func NewFirestoreJobStore(client *firestore.Client) *FirestoreJobStore {
	return &FirestoreJobStore{client: client}
}

func (s *FirestoreJobStore) Create(ctx context.Context, job *Job) error {
	now := time.Now()
	job.CreatedAt = now
	job.UpdatedAt = now
	_, err := s.client.Collection(jobsCollection).Doc(job.ID).Set(ctx, job)
	if err != nil {
		return fmt.Errorf("firestore create job %s: %w", job.ID, err)
	}
	return nil
}

func (s *FirestoreJobStore) Get(ctx context.Context, jobID string) (*Job, error) {
	doc, err := s.client.Collection(jobsCollection).Doc(jobID).Get(ctx)
	if err != nil {
		return nil, fmt.Errorf("firestore get job %s: %w", jobID, err)
	}
	var job Job
	if err := doc.DataTo(&job); err != nil {
		return nil, fmt.Errorf("firestore decode job %s: %w", jobID, err)
	}
	return &job, nil
}

func (s *FirestoreJobStore) SetProcessing(ctx context.Context, jobID string) error {
	_, err := s.client.Collection(jobsCollection).Doc(jobID).Update(ctx, []firestore.Update{
		{Path: "status", Value: JobStatusProcessing},
		{Path: "updatedAt", Value: time.Now()},
	})
	if err != nil {
		return fmt.Errorf("firestore set processing %s: %w", jobID, err)
	}
	return nil
}

func (s *FirestoreJobStore) SetCompleted(ctx context.Context, jobID, audioURL string, timepoints []TTSTimepoint) error {
	updates := []firestore.Update{
		{Path: "status", Value: JobStatusCompleted},
		{Path: "audioUrl", Value: audioURL},
		{Path: "updatedAt", Value: time.Now()},
	}
	if len(timepoints) > 0 {
		updates = append(updates, firestore.Update{Path: "timepoints", Value: timepoints})
	}
	_, err := s.client.Collection(jobsCollection).Doc(jobID).Update(ctx, updates)
	if err != nil {
		return fmt.Errorf("firestore set completed %s: %w", jobID, err)
	}
	return nil
}

func (s *FirestoreJobStore) SetFailed(ctx context.Context, jobID, errMsg string) error {
	_, err := s.client.Collection(jobsCollection).Doc(jobID).Update(ctx, []firestore.Update{
		{Path: "status", Value: JobStatusFailed},
		{Path: "errorMsg", Value: errMsg},
		{Path: "updatedAt", Value: time.Now()},
	})
	if err != nil {
		return fmt.Errorf("firestore set failed %s: %w", jobID, err)
	}
	return nil
}
