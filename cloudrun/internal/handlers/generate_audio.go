package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/google/generative-ai-go/genai"
	"google.golang.org/api/option"
)

// GenerateAudioRequest represents the request body for generateAudio endpoint
type GenerateAudioRequest struct {
	Text     string `json:"text"`
	Language string `json:"language"`
}

// GenerateAudioResponse represents the response for generateAudio endpoint
type GenerateAudioResponse struct {
	Success       bool   `json:"success"`
	ProcessedText string `json:"processedText"`
	OriginalText  string `json:"originalText"`
	Language      string `json:"language"`
	Message       string `json:"message"`
}

// GenerateAudioHandler handles POST /generateAudio
// This is a placeholder that processes text with Gemini AI
func GenerateAudioHandler(w http.ResponseWriter, r *http.Request) {
	// Only allow POST method
	if r.Method != http.MethodPost {
		http.Error(w, `{"error": "Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	// Parse request body
	var req GenerateAudioRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error": "Invalid request body"}`, http.StatusBadRequest)
		return
	}

	// Validate required field
	if req.Text == "" {
		http.Error(w, `{"error": "Text is required"}`, http.StatusBadRequest)
		return
	}

	// Default language
	if req.Language == "" {
		req.Language = "ja-JP"
	}

	log.Printf("generateAudio request: text=%q, language=%s", req.Text, req.Language)

	// Process text with Gemini
	processedText, err := processTextWithGemini(req.Text)
	if err != nil {
		log.Printf("Gemini API error: %v", err)
		http.Error(w, fmt.Sprintf(`{"error": "Failed to process text", "message": "%s"}`, err.Error()), http.StatusInternalServerError)
		return
	}

	response := GenerateAudioResponse{
		Success:       true,
		ProcessedText: processedText,
		OriginalText:  req.Text,
		Language:      req.Language,
		Message:       "Audio generation completed (placeholder)",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// processTextWithGemini processes text using Gemini AI
func processTextWithGemini(text string) (string, error) {
	ctx := context.Background()

	apiKey := os.Getenv("GEMINI_API_KEY")
	if apiKey == "" {
		return text, nil // Return original text if no API key
	}

	client, err := genai.NewClient(ctx, option.WithAPIKey(apiKey))
	if err != nil {
		return "", fmt.Errorf("failed to create Gemini client: %w", err)
	}
	defer client.Close()

	model := client.GenerativeModel("gemini-1.5-flash")

	prompt := fmt.Sprintf(`以下のテキストを音声読み上げ用に最適化してください。
句読点の位置を調整し、自然な読み上げになるようにしてください。
元の意味は変えないでください。

テキスト: %s`, text)

	resp, err := model.GenerateContent(ctx, genai.Text(prompt))
	if err != nil {
		return "", fmt.Errorf("failed to generate content: %w", err)
	}

	if len(resp.Candidates) == 0 || len(resp.Candidates[0].Content.Parts) == 0 {
		return text, nil // Return original if no response
	}

	// Extract text from response
	part := resp.Candidates[0].Content.Parts[0]
	if textPart, ok := part.(genai.Text); ok {
		return string(textPart), nil
	}

	return text, nil
}
