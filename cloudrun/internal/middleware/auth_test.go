package middleware

import (
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestAPIKeyAuth(t *testing.T) {
	// Handler that just returns 200 OK
	okHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	tests := []struct {
		name           string
		apiKeyEnv      string
		authHeader     string
		xApiKeyHeader  string
		wantStatusCode int
	}{
		{
			name:           "No API key configured - allow all",
			apiKeyEnv:      "",
			authHeader:     "",
			xApiKeyHeader:  "",
			wantStatusCode: http.StatusOK,
		},
		{
			name:           "Valid Bearer token",
			apiKeyEnv:      "test-api-key",
			authHeader:     "Bearer test-api-key",
			xApiKeyHeader:  "",
			wantStatusCode: http.StatusOK,
		},
		{
			name:           "Valid X-API-Key header",
			apiKeyEnv:      "test-api-key",
			authHeader:     "",
			xApiKeyHeader:  "test-api-key",
			wantStatusCode: http.StatusOK,
		},
		{
			name:           "Invalid Bearer token",
			apiKeyEnv:      "test-api-key",
			authHeader:     "Bearer wrong-key",
			xApiKeyHeader:  "",
			wantStatusCode: http.StatusUnauthorized,
		},
		{
			name:           "Invalid X-API-Key",
			apiKeyEnv:      "test-api-key",
			authHeader:     "",
			xApiKeyHeader:  "wrong-key",
			wantStatusCode: http.StatusUnauthorized,
		},
		{
			name:           "Missing auth when required",
			apiKeyEnv:      "test-api-key",
			authHeader:     "",
			xApiKeyHeader:  "",
			wantStatusCode: http.StatusUnauthorized,
		},
		{
			name:           "Case insensitive Bearer",
			apiKeyEnv:      "test-api-key",
			authHeader:     "bearer test-api-key",
			xApiKeyHeader:  "",
			wantStatusCode: http.StatusOK,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Set environment variable
			if tt.apiKeyEnv != "" {
				os.Setenv("API_KEY", tt.apiKeyEnv)
				defer os.Unsetenv("API_KEY")
			} else {
				os.Unsetenv("API_KEY")
			}

			req := httptest.NewRequest(http.MethodGet, "/test", nil)
			if tt.authHeader != "" {
				req.Header.Set("Authorization", tt.authHeader)
			}
			if tt.xApiKeyHeader != "" {
				req.Header.Set("X-API-Key", tt.xApiKeyHeader)
			}

			w := httptest.NewRecorder()

			handler := APIKeyAuth(okHandler)
			handler(w, req)

			resp := w.Result()
			defer resp.Body.Close()

			if resp.StatusCode != tt.wantStatusCode {
				t.Errorf("APIKeyAuth() status = %d, want %d", resp.StatusCode, tt.wantStatusCode)
			}
		})
	}
}
