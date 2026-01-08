package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	texttospeech "cloud.google.com/go/texttospeech/apiv1"
	"cloud.google.com/go/texttospeech/apiv1/texttospeechpb"
	"cloud.google.com/go/storage"
	"github.com/google/uuid"

	"github.com/entaku0818/voiceyourtext-cloudrun/internal/config"
)

const maxTextLength = 5000

// GenerateAudioTTSRequest represents the request body for generateAudioWithTTS endpoint
type GenerateAudioTTSRequest struct {
	Text     string `json:"text"`
	VoiceID  string `json:"voiceId"`
	Language string `json:"language"`
	Style    string `json:"style"`
}

// GenerateAudioTTSResponse represents the response for generateAudioWithTTS endpoint
type GenerateAudioTTSResponse struct {
	Success      bool                      `json:"success"`
	OriginalText string                    `json:"originalText"`
	Language     string                    `json:"language"`
	Voice        config.PublicVoiceOption  `json:"voice"`
	Style        string                    `json:"style"`
	AudioURL     string                    `json:"audioUrl"`
	Filename     string                    `json:"filename"`
	MimeType     string                    `json:"mimeType"`
	Message      string                    `json:"message"`
}

// ErrorResponseWithVoices represents an error response that includes available voices
type ErrorResponseWithVoices struct {
	Error           string                     `json:"error"`
	AvailableVoices []config.PublicVoiceOption `json:"availableVoices,omitempty"`
}

// GenerateAudioTTSHandler handles POST /generateAudioWithTTS
func GenerateAudioTTSHandler(w http.ResponseWriter, r *http.Request) {
	// Only allow POST method
	if r.Method != http.MethodPost {
		http.Error(w, `{"error": "Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	// Parse request body
	var req GenerateAudioTTSRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error": "Invalid request body"}`, http.StatusBadRequest)
		return
	}

	// Validate text
	if req.Text == "" {
		http.Error(w, `{"error": "Text is required"}`, http.StatusBadRequest)
		return
	}

	if len(req.Text) > maxTextLength {
		http.Error(w, fmt.Sprintf(`{"error": "Text too long. Maximum %d characters allowed."}`, maxTextLength), http.StatusBadRequest)
		return
	}

	// Default voice ID
	if req.VoiceID == "" {
		req.VoiceID = "en-us-female-a"
	}

	// Get voice configuration
	voice := config.GetVoiceByID(req.VoiceID)
	if voice == nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(ErrorResponseWithVoices{
			Error:           "Invalid voice ID",
			AvailableVoices: config.GetPublicVoices(),
		})
		return
	}

	// Use voice's language if not specified
	language := req.Language
	if language == "" {
		language = voice.Language
	}

	// Default style
	if req.Style == "" {
		req.Style = "cheerfully"
	}

	log.Printf("generateAudioWithTTS request: text=%q, voiceId=%s, language=%s, style=%s",
		req.Text, req.VoiceID, language, req.Style)

	// Generate audio using Google Cloud TTS
	audioContent, err := generateTTSAudio(req.Text, voice, language)
	if err != nil {
		log.Printf("TTS generation error: %v", err)
		http.Error(w, fmt.Sprintf(`{"error": "Failed to generate audio", "message": "%s"}`, err.Error()), http.StatusInternalServerError)
		return
	}

	// Generate unique filename
	filename := fmt.Sprintf("audio/%s_%d_%s.wav", req.VoiceID, time.Now().Unix(), uuid.New().String())

	// Upload to Cloud Storage
	audioURL, err := uploadToStorage(audioContent, filename, req.Text, req.VoiceID, language, req.Style)
	if err != nil {
		log.Printf("Storage upload error: %v", err)
		http.Error(w, fmt.Sprintf(`{"error": "Failed to save audio", "message": "%s"}`, err.Error()), http.StatusInternalServerError)
		return
	}

	response := GenerateAudioTTSResponse{
		Success:      true,
		OriginalText: req.Text,
		Language:     language,
		Voice:        voice.ToPublic(),
		Style:        req.Style,
		AudioURL:     audioURL,
		Filename:     filename,
		MimeType:     "audio/wav",
		Message:      "Audio generated and saved successfully",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// generateTTSAudio generates audio using Google Cloud Text-to-Speech API
func generateTTSAudio(text string, voice *config.VoiceOption, language string) ([]byte, error) {
	ctx := context.Background()

	client, err := texttospeech.NewClient(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to create TTS client: %w", err)
	}
	defer client.Close()

	// Determine SSML gender
	var ssmlGender texttospeechpb.SsmlVoiceGender
	if voice.Gender == "male" {
		ssmlGender = texttospeechpb.SsmlVoiceGender_MALE
	} else {
		ssmlGender = texttospeechpb.SsmlVoiceGender_FEMALE
	}

	// Build the request
	req := &texttospeechpb.SynthesizeSpeechRequest{
		Input: &texttospeechpb.SynthesisInput{
			InputSource: &texttospeechpb.SynthesisInput_Text{Text: text},
		},
		Voice: &texttospeechpb.VoiceSelectionParams{
			LanguageCode: language,
			Name:         voice.WavenetVoice,
			SsmlGender:   ssmlGender,
		},
		AudioConfig: &texttospeechpb.AudioConfig{
			AudioEncoding: texttospeechpb.AudioEncoding_LINEAR16,
		},
	}

	resp, err := client.SynthesizeSpeech(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to synthesize speech: %w", err)
	}

	return resp.AudioContent, nil
}

// uploadToStorage uploads audio to Google Cloud Storage
func uploadToStorage(audioContent []byte, filename, originalText, voiceID, language, style string) (string, error) {
	ctx := context.Background()

	bucketName := os.Getenv("STORAGE_BUCKET_NAME")
	if bucketName == "" {
		return "", fmt.Errorf("STORAGE_BUCKET_NAME environment variable not set")
	}

	client, err := storage.NewClient(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to create storage client: %w", err)
	}
	defer client.Close()

	bucket := client.Bucket(bucketName)
	obj := bucket.Object(filename)

	// Upload the file
	writer := obj.NewWriter(ctx)
	writer.ContentType = "audio/wav"
	writer.Metadata = map[string]string{
		"originalText": originalText,
		"voice":        voiceID,
		"language":     language,
		"style":        style,
		"timestamp":    fmt.Sprintf("%d", time.Now().Unix()),
	}

	if _, err := writer.Write(audioContent); err != nil {
		writer.Close()
		return "", fmt.Errorf("failed to write audio: %w", err)
	}

	if err := writer.Close(); err != nil {
		return "", fmt.Errorf("failed to close writer: %w", err)
	}

	// Make the object public
	if err := obj.ACL().Set(ctx, storage.AllUsers, storage.RoleReader); err != nil {
		return "", fmt.Errorf("failed to make object public: %w", err)
	}

	// Return public URL
	audioURL := fmt.Sprintf("https://storage.googleapis.com/%s/%s", bucketName, filename)
	return audioURL, nil
}
