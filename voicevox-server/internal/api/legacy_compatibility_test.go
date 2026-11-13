package api

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/entaku0818/voiceyourtext-voicevox/internal/policy"
)

// Freeze the response fields read by the pre-catalog iOS/Android clients.
// Do not reuse the new server response types: that would hide wire changes.
type legacyVoice struct {
	SpeakerID int    `json:"speakerId"`
	Character string `json:"character"`
	Style     string `json:"style"`
	Credit    string `json:"credit"`
	TermsURL  string `json:"termsUrl"`
}

type legacyVoices struct {
	Voices []legacyVoice `json:"voices"`
}

type legacyUsage struct {
	Plan      string    `json:"plan"`
	Used      int       `json:"used"`
	Limit     int       `json:"limit"`
	Remaining int       `json:"remaining"`
	ResetAt   time.Time `json:"resetAt"`
}

type legacyAudio struct {
	Audio    string  `json:"audio"`
	Format   string  `json:"format"`
	Duration float64 `json:"duration"`
	Phrases  []struct {
		Kana  string  `json:"kana"`
		Start float64 `json:"start"`
		End   float64 `json:"end"`
	} `json:"phrases"`
	Usage legacyUsage `json:"usage"`
}

func legacyCatalog(t *testing.T) legacyVoices {
	t.Helper()
	// Public GET /v1/voices from production revision voicevox-tts-00011-dvm,
	// captured 2026-10-30. Contains public character metadata only.
	data, err := os.ReadFile("testdata/legacy-voices.json")
	if err != nil {
		t.Fatal(err)
	}
	var result legacyVoices
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatal(err)
	}
	return result
}

func TestLegacyCatalogResponseRemainsCompatible(t *testing.T) {
	h, _, _ := newHandler()
	h.Policy = policy.Static{Policy: policy.Default()}
	rec := httptest.NewRecorder()
	h.Routes().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/v1/voices", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d: %s", rec.Code, rec.Body)
	}
	var got legacyVoices
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got, legacyCatalog(t)) {
		t.Fatalf("legacy character IDs, names, order or credits changed: %+v", got)
	}
}

func TestLegacyGenerationAndQuotaContract(t *testing.T) {
	for _, plan := range []struct {
		user  string
		limit int
		name  string
	}{{"free-user", 5000, "free"}, {"premium", 200000, "premium"}} {
		t.Run(plan.name, func(t *testing.T) {
			h, engine, store := newHandler()
			h.Policy = policy.Static{Policy: policy.Default()}
			for index, voice := range legacyCatalog(t).Voices {
				// Old clients send 300-character chunks without fetching /v1/config.
				text := strings.Repeat("あ", 300)
				request := fmt.Sprintf(`{"text":%q,"speakerId":%d,"speedScale":1}`, text, voice.SpeakerID)
				rec := synth(t, h, plan.user, "ok", request)
				if rec.Code != http.StatusOK {
					t.Fatalf("old speaker %d: status %d: %s", voice.SpeakerID, rec.Code, rec.Body)
				}
				var got legacyAudio
				if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
					t.Fatal(err)
				}
				data, err := base64.StdEncoding.DecodeString(got.Audio)
				if err != nil || string(data) != "RIFF"+text || got.Format != "wav" || got.Duration != 1.5 {
					t.Fatalf("legacy audio response failed: %+v, %v", got, err)
				}
				if len(got.Phrases) != 1 || got.Phrases[0].Kana != "テスト" || got.Phrases[0].Start != 0.1 || got.Phrases[0].End != 1.4 {
					t.Fatalf("legacy phrase response failed: %+v", got.Phrases)
				}
				used := (index + 1) * 300
				want := legacyUsage{plan.name, used, plan.limit, plan.limit - used, time.Date(2026, 10, 1, 0, 0, 0, 0, time.FixedZone("JST", 9*60*60))}
				if got.Usage.Plan != want.Plan || got.Usage.Used != want.Used || got.Usage.Limit != want.Limit || got.Usage.Remaining != want.Remaining || !got.Usage.ResetAt.Equal(want.ResetAt) {
					t.Fatalf("legacy quota response failed: %+v, want %+v", got.Usage, want)
				}
			}
			// Existing usage remains visible through GET and the old 429 payload.
			if _, err := store.Reserve(context.Background(), plan.user, plan.limit-1800, plan.limit, now); err != nil {
				t.Fatal(err)
			}
			req := httptest.NewRequest(http.MethodGet, "/v1/quota", nil)
			req.Header.Set("X-Firebase-AppCheck", "ok")
			req.Header.Set("X-User-ID", plan.user)
			rec := httptest.NewRecorder()
			h.Routes().ServeHTTP(rec, req)
			var got legacyUsage
			if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil || rec.Code != http.StatusOK || got.Used != plan.limit || got.Limit != plan.limit || got.Remaining != 0 || got.Plan != plan.name || got.ResetAt.IsZero() {
				t.Fatalf("legacy GET quota failed: %d %s, %v", rec.Code, rec.Body, err)
			}
			rec = synth(t, h, plan.user, "ok", `{"text":"あ","speakerId":14,"speedScale":1}`)
			var exceeded struct {
				Error string      `json:"error"`
				Usage legacyUsage `json:"usage"`
			}
			if err := json.Unmarshal(rec.Body.Bytes(), &exceeded); err != nil || rec.Code != http.StatusTooManyRequests || exceeded.Error != "quota_exceeded" || !reflect.DeepEqual(exceeded.Usage, got) || engine.calls != 6 {
				t.Fatalf("legacy 429 response failed: %d %s, %v", rec.Code, rec.Body, err)
			}
		})
	}
}
