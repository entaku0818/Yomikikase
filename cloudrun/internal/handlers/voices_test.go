package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGetVoicesHandler(t *testing.T) {
	tests := []struct {
		name           string
		method         string
		queryParams    string
		wantStatusCode int
		wantSuccess    bool
	}{
		{
			name:           "GET all voices",
			method:         http.MethodGet,
			queryParams:    "",
			wantStatusCode: http.StatusOK,
			wantSuccess:    true,
		},
		{
			name:           "GET voices filtered by language",
			method:         http.MethodGet,
			queryParams:    "?language=ja-JP",
			wantStatusCode: http.StatusOK,
			wantSuccess:    true,
		},
		{
			name:           "GET voices with non-existing language",
			method:         http.MethodGet,
			queryParams:    "?language=xx-XX",
			wantStatusCode: http.StatusOK,
			wantSuccess:    true,
		},
		{
			name:           "POST method not allowed",
			method:         http.MethodPost,
			queryParams:    "",
			wantStatusCode: http.StatusMethodNotAllowed,
			wantSuccess:    false,
		},
		{
			name:           "PUT method not allowed",
			method:         http.MethodPut,
			queryParams:    "",
			wantStatusCode: http.StatusMethodNotAllowed,
			wantSuccess:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(tt.method, "/getVoices"+tt.queryParams, nil)
			w := httptest.NewRecorder()

			GetVoicesHandler(w, req)

			resp := w.Result()
			defer resp.Body.Close()

			if resp.StatusCode != tt.wantStatusCode {
				t.Errorf("GetVoicesHandler() status = %d, want %d", resp.StatusCode, tt.wantStatusCode)
			}

			if tt.wantStatusCode == http.StatusOK {
				var response GetVoicesResponse
				if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
					t.Errorf("Failed to decode response: %v", err)
				}

				if response.Success != tt.wantSuccess {
					t.Errorf("GetVoicesHandler() success = %v, want %v", response.Success, tt.wantSuccess)
				}

				if response.Voices == nil {
					t.Error("GetVoicesHandler() voices should not be nil")
				}
			}
		})
	}
}

func TestGetVoicesHandler_FilteredResults(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/getVoices?language=ja-JP", nil)
	w := httptest.NewRecorder()

	GetVoicesHandler(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	var response GetVoicesResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	for _, voice := range response.Voices {
		if voice.Language != "ja-JP" {
			t.Errorf("GetVoicesHandler() returned voice with language %q, want ja-JP", voice.Language)
		}
	}
}

func TestGetVoicesHandler_ContentType(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/getVoices", nil)
	w := httptest.NewRecorder()

	GetVoicesHandler(w, req)

	resp := w.Result()
	defer resp.Body.Close()

	contentType := resp.Header.Get("Content-Type")
	if contentType != "application/json" {
		t.Errorf("GetVoicesHandler() Content-Type = %q, want application/json", contentType)
	}
}
