package main

import (
	"log"
	"net/http"
	"os"

	"github.com/rs/cors"

	"github.com/entaku0818/voiceyourtext-cloudrun/internal/handlers"
	"github.com/entaku0818/voiceyourtext-cloudrun/internal/middleware"
)

func main() {
	// Get port from environment variable (Cloud Run sets this)
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Create router
	mux := http.NewServeMux()

	// Register handlers
	// Public endpoints (no auth required)
	mux.HandleFunc("/getVoices", handlers.GetVoicesHandler)

	// Protected endpoints (API key required)
	mux.HandleFunc("/generateAudio", middleware.APIKeyAuth(handlers.GenerateAudioHandler))
	mux.HandleFunc("/generateAudioWithTTS", middleware.APIKeyAuth(handlers.GenerateAudioTTSHandler))

	// Health check endpoint
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status": "healthy"}`))
	})

	// Root endpoint
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"service": "voiceyourtext-tts", "version": "1.0.0", "endpoints": ["/getVoices", "/generateAudio", "/generateAudioWithTTS", "/health"]}`))
	})

	// Setup CORS
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
