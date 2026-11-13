package api

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/entaku0818/voiceyourtext-voicevox/internal/audio"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/entitlement"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/policy"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/quota"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/voices"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/voicevox"
)

type fakeAppCheck struct{ valid string }

func (f fakeAppCheck) Verify(_ context.Context, token string) error {
	if token != f.valid {
		return errors.New("bad token")
	}
	return nil
}

type fakeEngine struct {
	calls int
	err   error
}

func (f *fakeEngine) Synthesize(_ context.Context, text string, _ int, _ voicevox.Options) (voicevox.Result, error) {
	f.calls++
	if f.err != nil {
		return voicevox.Result{}, f.err
	}
	return voicevox.Result{WAV: []byte("RIFF" + text), Duration: 1.5, Phrases: []voicevox.Phrase{{Kana: "テスト", Start: 0.1, End: 1.4}}}, nil
}

type errEntitlement struct{}

func (errEntitlement) IsPremium(context.Context, string) (bool, error) {
	return true, errors.New("down")
}

var now = time.Date(2026, 9, 27, 12, 0, 0, 0, time.UTC)

func newHandler() (*Handler, *fakeEngine, *quota.Memory) {
	engine := &fakeEngine{}
	store := &quota.Memory{}
	p := policy.Default()
	p.Voicevox = policy.Voicevox{Enabled: true, FreeMonthly: 10, PremiumMonthly: 100, MaxRequestChars: 50}
	return &Handler{
		AppCheck:    fakeAppCheck{valid: "ok"},
		Entitlement: entitlement.Static{Premium: map[string]bool{"premium": true}},
		Quota:       store,
		Engine:      engine,
		Encoder:     audio.Passthrough{},
		Policy:      policy.Static{Policy: p},
		Now:         func() time.Time { return now },
	}, engine, store
}

func synth(t *testing.T, h *Handler, user, token, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/v1/synthesize", strings.NewReader(body))
	if token != "" {
		req.Header.Set("X-Firebase-AppCheck", token)
	}
	req.Header.Set("X-User-ID", user)
	rec := httptest.NewRecorder()
	h.Routes().ServeHTTP(rec, req)
	return rec
}

func decode(t *testing.T, rec *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	var m map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &m); err != nil {
		t.Fatalf("decode %q: %v", rec.Body.String(), err)
	}
	return m
}

func TestSynthesizeReturnsAudioAndUsage(t *testing.T) {
	h, _, _ := newHandler()
	rec := synth(t, h, "free-user", "ok", `{"text":"こんにちは","speakerId":14}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d: %s", rec.Code, rec.Body)
	}
	m := decode(t, rec)
	usage := m["usage"].(map[string]any)
	if usage["plan"] != "free" || usage["used"].(float64) != 5 || usage["remaining"].(float64) != 5 {
		t.Errorf("usage = %v", usage)
	}
	if m["format"] != "wav" || m["audio"] == "" || len(m["phrases"].([]any)) != 1 {
		t.Errorf("response = %v", m)
	}
}

func TestAppCheckIsRequired(t *testing.T) {
	h, engine, _ := newHandler()
	if rec := synth(t, h, "u", "", `{"text":"あ","speakerId":14}`); rec.Code != http.StatusUnauthorized {
		t.Errorf("missing token: status %d", rec.Code)
	}
	if rec := synth(t, h, "u", "forged", `{"text":"あ","speakerId":14}`); rec.Code != http.StatusUnauthorized {
		t.Errorf("forged token: status %d", rec.Code)
	}
	if engine.calls != 0 {
		t.Errorf("engine called %d times without valid App Check", engine.calls)
	}
}

func TestRejectsInvalidUserID(t *testing.T) {
	h, _, _ := newHandler()
	for _, id := range []string{"", "a b", strings.Repeat("x", 129), "../etc"} {
		if rec := synth(t, h, id, "ok", `{"text":"あ","speakerId":14}`); rec.Code != http.StatusBadRequest {
			t.Errorf("user %q: status %d", id, rec.Code)
		}
	}
	if rec := synth(t, h, "$RCAnonymousID:0123abcd", "ok", `{"text":"あ","speakerId":14}`); rec.Code != http.StatusOK {
		t.Errorf("RevenueCat anonymous id rejected: %d %s", rec.Code, rec.Body)
	}
}

func TestOnlyAllowedSpeakers(t *testing.T) {
	h, engine, _ := newHandler()
	// 30 は No.7（有料アプリは要ライセンス）で許可リストにない
	rec := synth(t, h, "u", "ok", `{"text":"あ","speakerId":30}`)
	if rec.Code != http.StatusBadRequest || decode(t, rec)["error"] != "speaker_not_allowed" {
		t.Errorf("status %d: %s", rec.Code, rec.Body)
	}
	if engine.calls != 0 {
		t.Error("engine called for a speaker outside the allow list")
	}
}

func TestFreeQuotaIsEnforced(t *testing.T) {
	h, engine, _ := newHandler()
	if rec := synth(t, h, "u", "ok", `{"text":"あいうえおかきく","speakerId":14}`); rec.Code != http.StatusOK {
		t.Fatalf("first: %d", rec.Code)
	}
	// 8 + 3 = 11 > 10
	rec := synth(t, h, "u", "ok", `{"text":"けこさ","speakerId":14}`)
	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("status %d: %s", rec.Code, rec.Body)
	}
	m := decode(t, rec)
	if m["error"] != "quota_exceeded" || m["usage"].(map[string]any)["used"].(float64) != 8 {
		t.Errorf("response = %v", m)
	}
	if engine.calls != 1 {
		t.Errorf("engine called %d times, want 1", engine.calls)
	}
	// 残り2文字ならまだ通る
	if rec := synth(t, h, "u", "ok", `{"text":"けこ","speakerId":14}`); rec.Code != http.StatusOK {
		t.Errorf("remaining chars rejected: %d", rec.Code)
	}
}

func TestPremiumGetsLargerQuota(t *testing.T) {
	h, _, _ := newHandler()
	rec := synth(t, h, "premium", "ok", `{"text":"`+strings.Repeat("あ", 40)+`","speakerId":14}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d: %s", rec.Code, rec.Body)
	}
	usage := decode(t, rec)["usage"].(map[string]any)
	if usage["plan"] != "premium" || usage["limit"].(float64) != 100 {
		t.Errorf("usage = %v", usage)
	}
}

func TestEntitlementOutageFallsBackToFree(t *testing.T) {
	h, _, _ := newHandler()
	h.Entitlement = errEntitlement{}
	rec := synth(t, h, "premium", "ok", `{"text":"あ","speakerId":14}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d", rec.Code)
	}
	if plan := decode(t, rec)["usage"].(map[string]any)["plan"]; plan != "free" {
		t.Errorf("plan = %v, want free while RevenueCat is down", plan)
	}
}

func TestEngineFailureRefundsQuota(t *testing.T) {
	h, engine, store := newHandler()
	engine.err = errors.New("engine down")
	if rec := synth(t, h, "u", "ok", `{"text":"あいう","speakerId":14}`); rec.Code != http.StatusBadGateway {
		t.Fatalf("status %d", rec.Code)
	}
	u, _ := store.Get(context.Background(), "u", 10, now)
	if u.Used != 0 {
		t.Errorf("used = %d after failed synthesis, want 0", u.Used)
	}
}

func TestTextValidation(t *testing.T) {
	h, _, _ := newHandler()
	cases := map[string]int{
		`{"text":"   ","speakerId":14}`:                             http.StatusBadRequest,
		`{"text":"` + strings.Repeat("あ", 51) + `","speakerId":14}`: http.StatusRequestEntityTooLarge,
		`not json`: http.StatusBadRequest,
	}
	for body, want := range cases {
		if rec := synth(t, h, "premium", "ok", body); rec.Code != want {
			t.Errorf("%.20s: status %d, want %d", body, rec.Code, want)
		}
	}
}

func TestCountCharsIgnoresSurroundingSpaceAndCountsRunes(t *testing.T) {
	if n := CountChars("  第3回の会議。\n"); n != 7 {
		t.Errorf("CountChars = %d, want 7", n)
	}
}

func TestQuotaEndpoint(t *testing.T) {
	h, _, _ := newHandler()
	synth(t, h, "u", "ok", `{"text":"あいう","speakerId":14}`)
	req := httptest.NewRequest(http.MethodGet, "/v1/quota", nil)
	req.Header.Set("X-Firebase-AppCheck", "ok")
	req.Header.Set("X-User-ID", "u")
	rec := httptest.NewRecorder()
	h.Routes().ServeHTTP(rec, req)
	m := decode(t, rec)
	if m["used"].(float64) != 3 || m["remaining"].(float64) != 7 {
		t.Errorf("quota = %v", m)
	}
	// 月の区切りは日本時間の月初
	if m["resetAt"] != "2026-10-01T00:00:00+09:00" {
		t.Errorf("resetAt = %v", m["resetAt"])
	}
}

func TestVoicesAreListedWithCredits(t *testing.T) {
	h, _, _ := newHandler()
	rec := httptest.NewRecorder()
	h.Routes().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/v1/voices", nil))
	list := decode(t, rec)["voices"].([]any)
	if len(list) != 6 {
		t.Fatalf("voices = %d, want 6", len(list))
	}
	for _, v := range list {
		if c := v.(map[string]any)["credit"].(string); !strings.HasPrefix(c, "VOICEVOX:") {
			t.Errorf("credit %q must start with VOICEVOX:", c)
		}
	}
}

type changingPolicy struct {
	current policy.Policy
	err     error
}

func TestCatalogChangesApplyToListAndGenerationTogether(t *testing.T) {
	h, engine, store := newHandler()
	p, _ := h.Policy.Load(context.Background())
	source := &changingPolicy{current: p}
	h.Policy = source
	id := 401
	source.current.Revision = "catalog.2"
	source.current.Catalog.DefaultSpeakerID = &id
	source.current.Catalog.Voices[0].Enabled = false
	source.current.Catalog.Voices = append([]voices.Voice{{SpeakerID: id, Character: "new server character", Style: "normal", Credit: "test credit", TermsURL: "https://example.com/terms", Enabled: true}}, source.current.Catalog.Voices...)
	rec := httptest.NewRecorder()
	h.Routes().ServeHTTP(rec, httptest.NewRequest("GET", "/v1/voices", nil))
	body := decode(t, rec)
	list := body["voices"].([]any)
	if rec.Code != 200 || body["defaultSpeakerId"] != float64(id) || list[0].(map[string]any)["speakerId"] != float64(id) || len(list) != 6 || len(body["credits"].([]any)) != 7 || rec.Header().Get("Cache-Control") != "no-store" {
		t.Fatal(body)
	}
	if rec := synth(t, h, "premium", "ok", `{"text":"あ","speakerId":14}`); rec.Code != 400 || engine.calls != 0 {
		t.Fatal(rec.Code, engine.calls)
	}
	u, _ := store.Get(context.Background(), "premium", 100, now)
	if u.Used != 0 {
		t.Fatal("disabled voice consumed quota")
	}
	if rec := synth(t, h, "premium", "ok", `{"text":"あ","speakerId":401}`); rec.Code != 200 || engine.calls != 1 {
		t.Fatal(rec.Code, engine.calls)
	}
	source.err = errors.New("unavailable")
	rec = httptest.NewRecorder()
	h.Routes().ServeHTTP(rec, httptest.NewRequest("GET", "/v1/voices", nil))
	if rec.Code != 503 {
		t.Fatal("must not return a stale/default list")
	}
}

func (s *changingPolicy) Load(context.Context) (policy.Policy, error) { return s.current, s.err }

func TestPolicyChangeAppliesToNextRequestWithoutRestart(t *testing.T) {
	h, engine, _ := newHandler()
	p, _ := h.Policy.Load(context.Background())
	source := &changingPolicy{current: p}
	h.Policy = source
	if rec := synth(t, h, "premium", "ok", `{"text":"あいうえお","speakerId":14}`); rec.Code != 200 {
		t.Fatal(rec.Body)
	}
	source.current.Revision = "lowered"
	source.current.Voicevox.PremiumMonthly = 5
	rec := synth(t, h, "premium", "ok", `{"text":"か","speakerId":14}`)
	if rec.Code != 429 || engine.calls != 1 {
		t.Fatalf("not enforced: %d calls=%d", rec.Code, engine.calls)
	}
	u := decode(t, rec)["usage"].(map[string]any)
	if u["policyRevision"] != "lowered" || u["limit"] != float64(5) {
		t.Fatalf("stale response: %v", u)
	}
	source.current.Voicevox.PremiumMonthly = 100
	source.current.Voicevox.MaxRequestChars = 1
	if rec := synth(t, h, "premium", "ok", `{"text":"あい","speakerId":14}`); rec.Code != 413 {
		t.Fatalf("request cap not enforced: %d", rec.Code)
	}
}

func TestDisabledMissingAndInvalidPolicyDoNotGenerate(t *testing.T) {
	h, engine, store := newHandler()
	p, _ := h.Policy.Load(context.Background())
	source := &changingPolicy{current: p}
	h.Policy = source
	source.current.Voicevox.Enabled = false
	if rec := synth(t, h, "premium", "ok", `{"text":"あ","speakerId":14}`); rec.Code != 503 {
		t.Fatal(rec.Code)
	}
	source.current.Voicevox.Enabled = true
	source.err = errors.New("unavailable")
	if rec := synth(t, h, "premium", "ok", `{"text":"あ","speakerId":14}`); rec.Code != 503 {
		t.Fatal(rec.Code)
	}
	source.err = nil
	source.current.Voicevox.MaxRequestChars = 0
	if rec := synth(t, h, "premium", "ok", `{"text":"あ","speakerId":14}`); rec.Code != 503 {
		t.Fatal(rec.Code)
	}
	h.Policy = nil
	if rec := synth(t, h, "premium", "ok", `{"text":"あ","speakerId":14}`); rec.Code != 503 {
		t.Fatal(rec.Code)
	}
	u, _ := store.Get(context.Background(), "premium", 100, now)
	if engine.calls != 0 || u.Used != 0 {
		t.Fatalf("failed closed incorrectly: calls=%d used=%d", engine.calls, u.Used)
	}
}

func TestPublicConfigAndQuotaSharePolicy(t *testing.T) {
	h, _, _ := newHandler()
	rec := httptest.NewRecorder()
	h.Routes().ServeHTTP(rec, httptest.NewRequest("GET", "/v1/config", nil))
	p := decode(t, rec)
	if rec.Code != 200 || rec.Header().Get("Cache-Control") != "no-store" || p["voicevox"].(map[string]any)["maxRequestChars"] != float64(50) {
		t.Fatal(rec.Body)
	}
	if strings.Contains(rec.Body.String(), "gemini") || strings.Contains(rec.Body.String(), "Budget") {
		t.Fatal("unreleased/private config exposed")
	}
}
