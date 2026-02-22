package jobs

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	cloudtasks "cloud.google.com/go/cloudtasks/apiv2"
	taskspb "cloud.google.com/go/cloudtasks/apiv2/cloudtaskspb"
)

// CloudTasksQueue is the Cloud Tasks-backed implementation of TaskQueue.
type CloudTasksQueue struct {
	client     *cloudtasks.Client
	queuePath  string
	processURL string
	apiKey     string
}

// NewCloudTasksQueue creates a CloudTasksQueue from environment variables.
// Required env vars: GOOGLE_CLOUD_PROJECT, CLOUD_TASKS_LOCATION, CLOUD_TASKS_QUEUE, SERVICE_URL, API_KEY
func NewCloudTasksQueue(client *cloudtasks.Client) *CloudTasksQueue {
	project := os.Getenv("GOOGLE_CLOUD_PROJECT")
	location := os.Getenv("CLOUD_TASKS_LOCATION") // e.g. "asia-northeast1"
	queue := os.Getenv("CLOUD_TASKS_QUEUE")        // e.g. "tts-jobs"
	serviceURL := os.Getenv("SERVICE_URL")         // Cloud Run URL

	return &CloudTasksQueue{
		client:     client,
		queuePath:  fmt.Sprintf("projects/%s/locations/%s/queues/%s", project, location, queue),
		processURL: serviceURL + "/jobs/process",
		apiKey:     os.Getenv("API_KEY"),
	}
}

type processTaskPayload struct {
	JobID string `json:"jobId"`
}

func (q *CloudTasksQueue) Enqueue(ctx context.Context, jobID string) error {
	body, err := json.Marshal(processTaskPayload{JobID: jobID})
	if err != nil {
		return fmt.Errorf("marshal task payload: %w", err)
	}

	req := &taskspb.CreateTaskRequest{
		Parent: q.queuePath,
		Task: &taskspb.Task{
			MessageType: &taskspb.Task_HttpRequest{
				HttpRequest: &taskspb.HttpRequest{
					HttpMethod: taskspb.HttpMethod_POST,
					Url:        q.processURL,
					Headers: map[string]string{
						"Content-Type": "application/json",
						"X-API-Key":    q.apiKey,
					},
					Body: body,
				},
			},
		},
	}

	_, err = q.client.CreateTask(ctx, req)
	if err != nil {
		return fmt.Errorf("cloud tasks enqueue job %s: %w", jobID, err)
	}
	return nil
}
