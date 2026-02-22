package main

import (
	"context"
	"log"
	"net/http"
	"os"

	cloudtasks "cloud.google.com/go/cloudtasks/apiv2"
	"cloud.google.com/go/firestore"
	"cloud.google.com/go/storage"
	firebase "firebase.google.com/go/v4"
	"github.com/rs/cors"

	"github.com/entaku0818/voiceyourtext-cloudrun/internal/handlers"
	"github.com/entaku0818/voiceyourtext-cloudrun/internal/jobs"
	"github.com/entaku0818/voiceyourtext-cloudrun/internal/middleware"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	ctx := context.Background()

	// Firestore
	projectID := os.Getenv("GOOGLE_CLOUD_PROJECT")
	firestoreClient, err := firestore.NewClient(ctx, projectID)
	if err != nil {
		log.Fatalf("Failed to create Firestore client: %v", err)
	}
	defer firestoreClient.Close()

	// Cloud Tasks
	tasksClient, err := cloudtasks.NewClient(ctx)
	if err != nil {
		log.Fatalf("Failed to create Cloud Tasks client: %v", err)
	}
	defer tasksClient.Close()

	// Firebase (FCM)
	firebaseApp, err := firebase.NewApp(ctx, nil)
	if err != nil {
		log.Fatalf("Failed to create Firebase app: %v", err)
	}
	messagingClient, err := firebaseApp.Messaging(ctx)
	if err != nil {
		log.Fatalf("Failed to create FCM messaging client: %v", err)
	}

	// GCS
	gcsClient, err := storage.NewClient(ctx)
	if err != nil {
		log.Fatalf("Failed to create GCS client: %v", err)
	}
	defer gcsClient.Close()

	// Job deps
	jobDeps := &handlers.JobDeps{
		Store:    jobs.NewFirestoreJobStore(firestoreClient),
		Queue:    jobs.NewCloudTasksQueue(tasksClient),
		Gen:      &jobs.CloudTTSGenerator{},
		Storage:  jobs.NewGCSAudioStorage(gcsClient),
		Notifier: jobs.NewFCMNotifier(messagingClient),
	}

	// Router
	mux := http.NewServeMux()

	// Public endpoints
	mux.HandleFunc("/getVoices", handlers.GetVoicesHandler)

	// Protected endpoints (API key required)
	mux.HandleFunc("/generateAudio", middleware.APIKeyAuth(handlers.GenerateAudioHandler))
	mux.HandleFunc("/generateAudioWithTTS", middleware.APIKeyAuth(handlers.GenerateAudioTTSHandler))

	// Job endpoints
	mux.HandleFunc("/jobs", middleware.APIKeyAuth(jobDeps.CreateJobHandler))
	mux.HandleFunc("/jobs/process", middleware.APIKeyAuth(jobDeps.ProcessJobHandler))
	mux.HandleFunc("/jobs/", middleware.APIKeyAuth(jobDeps.GetJobHandler))

	// Health check
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status": "healthy"}`))
	})

	// Root
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"service": "voiceyourtext-tts", "version": "1.0.0"}`))
	})

	corsHandler := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "OPTIONS"},
		AllowedHeaders:   []string{"Content-Type", "Authorization", "X-API-Key"},
		AllowCredentials: false,
	})

	handler := corsHandler.Handler(mux)

	log.Printf("Starting server on port %s", port)
	if err := http.ListenAndServe(":"+port, handler); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
