package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/entaku0818/voiceyourtext-cloudrun/internal/config"
)

// GetVoicesResponse represents the response for getVoices endpoint
type GetVoicesResponse struct {
	Success bool                       `json:"success"`
	Voices  []config.PublicVoiceOption `json:"voices"`
}

// GetVoicesHandler handles GET /getVoices
func GetVoicesHandler(w http.ResponseWriter, r *http.Request) {
	// Only allow GET method
	if r.Method != http.MethodGet {
		http.Error(w, `{"error": "Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	// Get optional language filter
	language := r.URL.Query().Get("language")

	var voices []config.PublicVoiceOption
	if language != "" {
		voices = config.GetPublicVoicesByLanguage(language)
	} else {
		voices = config.GetPublicVoices()
	}

	response := GetVoicesResponse{
		Success: true,
		Voices:  voices,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}
