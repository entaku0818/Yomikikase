package middleware

import (
	"net/http"
	"os"
	"strings"
)

// APIKeyAuth is a middleware that validates API key
func APIKeyAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		apiKey := os.Getenv("API_KEY")

		// If no API key is configured, skip authentication
		if apiKey == "" {
			next(w, r)
			return
		}

		// Check Authorization header (Bearer token)
		authHeader := r.Header.Get("Authorization")
		if authHeader != "" {
			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) == 2 && strings.ToLower(parts[0]) == "bearer" {
				if parts[1] == apiKey {
					next(w, r)
					return
				}
			}
		}

		// Check X-API-Key header
		xApiKey := r.Header.Get("X-API-Key")
		if xApiKey == apiKey {
			next(w, r)
			return
		}

		// Unauthorized
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		w.Write([]byte(`{"error": "Unauthorized", "message": "Invalid or missing API key"}`))
	}
}
