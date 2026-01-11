package handlers

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"

	"cloud.google.com/go/storage"
	"github.com/google/uuid"
	texttospeech "google.golang.org/api/texttospeech/v1beta1"

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

// Timepoint represents a word timing for highlighting
type Timepoint struct {
	MarkName    string  `json:"markName"`
	TimeSeconds float64 `json:"timeSeconds"`
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
	Timepoints   []Timepoint               `json:"timepoints,omitempty"`
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

	// Generate audio using Google Cloud TTS with timepoints
	audioContent, timepoints, err := generateTTSAudioWithTimepoints(req.Text, voice, language)
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
		Timepoints:   timepoints,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// WordInfo stores information about a word's position in the original text
type WordInfo struct {
	Word       string
	StartIndex int
	EndIndex   int
}

// textToSSMLWithMarks converts plain text to SSML with marks before each word
// Returns the SSML string and a slice of WordInfo for mapping marks to text positions
func textToSSMLWithMarks(text string) (string, []WordInfo) {
	// Split text into words while preserving positions
	// Match words (including Japanese characters) and whitespace/punctuation
	wordRegex := regexp.MustCompile(`[\p{L}\p{N}]+`)
	matches := wordRegex.FindAllStringIndex(text, -1)

	var words []WordInfo
	for _, match := range matches {
		words = append(words, WordInfo{
			Word:       text[match[0]:match[1]],
			StartIndex: match[0],
			EndIndex:   match[1],
		})
	}

	// Build SSML with marks
	var ssmlBuilder strings.Builder
	ssmlBuilder.WriteString("<speak>")

	lastIndex := 0
	for i, word := range words {
		// Add any text before this word (spaces, punctuation)
		if word.StartIndex > lastIndex {
			ssmlBuilder.WriteString(escapeXML(text[lastIndex:word.StartIndex]))
		}
		// Add mark and word
		ssmlBuilder.WriteString(fmt.Sprintf("<mark name=\"%d\"/>%s", i, escapeXML(word.Word)))
		lastIndex = word.EndIndex
	}
	// Add any remaining text after the last word
	if lastIndex < len(text) {
		ssmlBuilder.WriteString(escapeXML(text[lastIndex:]))
	}

	ssmlBuilder.WriteString("</speak>")
	return ssmlBuilder.String(), words
}

// escapeXML escapes special characters for XML/SSML
func escapeXML(s string) string {
	s = strings.ReplaceAll(s, "&", "&amp;")
	s = strings.ReplaceAll(s, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	s = strings.ReplaceAll(s, "'", "&apos;")
	s = strings.ReplaceAll(s, "\"", "&quot;")
	return s
}

// generateTTSAudioWithTimepoints generates audio with word timing information using v1beta1 API
func generateTTSAudioWithTimepoints(text string, voice *config.VoiceOption, language string) ([]byte, []Timepoint, error) {
	ctx := context.Background()

	// Create TTS service using v1beta1 API (supports timepoints)
	service, err := texttospeech.NewService(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create TTS service: %w", err)
	}

	// Convert text to SSML with marks
	ssml, words := textToSSMLWithMarks(text)
	log.Printf("Generated SSML: %s", ssml)
	log.Printf("Word count: %d", len(words))

	// Determine SSML gender
	ssmlGender := "FEMALE"
	if voice.Gender == "male" {
		ssmlGender = "MALE"
	}

	// Build the request with SSML and timepoints enabled
	req := &texttospeech.SynthesizeSpeechRequest{
		Input: &texttospeech.SynthesisInput{
			Ssml: ssml,
		},
		Voice: &texttospeech.VoiceSelectionParams{
			LanguageCode: language,
			Name:         voice.WavenetVoice,
			SsmlGender:   ssmlGender,
		},
		AudioConfig: &texttospeech.AudioConfig{
			AudioEncoding: "LINEAR16",
		},
		EnableTimePointing: []string{"SSML_MARK"},
	}

	resp, err := service.Text.Synthesize(req).Context(ctx).Do()
	if err != nil {
		return nil, nil, fmt.Errorf("failed to synthesize speech: %w", err)
	}

	// Decode base64 audio content
	audioContent, err := base64.StdEncoding.DecodeString(resp.AudioContent)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to decode audio content: %w", err)
	}

	// Convert Google's timepoints to our format with text position info
	var timepoints []Timepoint
	for _, tp := range resp.Timepoints {
		markIndex := 0
		fmt.Sscanf(tp.MarkName, "%d", &markIndex)

		// Store the mark name with the original text position
		if markIndex < len(words) {
			timepoints = append(timepoints, Timepoint{
				MarkName:    fmt.Sprintf("%d:%d:%d", markIndex, words[markIndex].StartIndex, words[markIndex].EndIndex),
				TimeSeconds: tp.TimeSeconds,
			})
		}
	}

	log.Printf("Generated %d timepoints", len(timepoints))
	return audioContent, timepoints, nil
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
