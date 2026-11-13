package api

import (
	"context"
	"fmt"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/entaku0818/voiceyourtext-voicevox/internal/voicevox"
)

type countEntitlement struct{ calls atomic.Int32 }

func (e *countEntitlement) IsPremium(context.Context, string) (bool, error) {
	e.calls.Add(1)
	return false, nil
}

type countVerifier struct{ calls atomic.Int32 }

func (v *countVerifier) Verify(context.Context, string) error { v.calls.Add(1); return nil }

func TestInvalidBodiesDoNotReachEntitlementsOrQuota(t *testing.T) {
	cases := []struct {
		name, body string
		chunked    bool
		status     int
	}{
		{"trailing object", `{"text":"あ","speakerId":14} {}`, false, 400},
		{"trailing garbage", `{"text":"あ","speakerId":14} no`, false, 400},
		{"oversized length", strings.Repeat(" ", maxRequestBytes+1), false, 413},
		{"oversized stream", `{"text":"あ","speakerId":14}` + strings.Repeat(" ", maxRequestBytes), true, 400},
		{"unsupported speaker", `{"text":"あ","speakerId":30}`, false, 400},
		{"empty", `{"text":"","speakerId":14}`, false, 400},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			h, engine, store := newHandler()
			e := &countEntitlement{}
			h.Entitlement = e
			req := httptest.NewRequest("POST", "/v1/synthesize", strings.NewReader(tc.body))
			if tc.chunked {
				req.ContentLength = -1
			}
			req.Header.Set("X-Firebase-AppCheck", "ok")
			req.Header.Set("X-User-ID", "u")
			rec := httptest.NewRecorder()
			h.Routes().ServeHTTP(rec, req)
			usage, _ := store.Get(context.Background(), "u", 10, now)
			if rec.Code != tc.status || e.calls.Load() != 0 || engine.calls != 0 || usage.Used != 0 {
				t.Fatalf("code=%d entitlement=%d engine=%d usage=%d", rec.Code, e.calls.Load(), engine.calls, usage.Used)
			}
		})
	}
	h, _, _ := newHandler()
	if r := synth(t, h, "u", "ok", `{"text":"あ","speakerId":14,"futureField":true} `); r.Code != 200 {
		t.Fatalf("forward compatible body: %d", r.Code)
	}
}

func TestRateLimitRunsBeforeAuthenticationAndSurvivesRoutesCalls(t *testing.T) {
	h, _, _ := newHandler()
	v := &countVerifier{}
	h.AppCheck = v
	fixed := time.Now()
	h.Guard = NewGuard()
	h.Guard.now = func() time.Time { return fixed }
	for i := 0; i < 20; i++ {
		synth(t, h, "u", "ok", `not json`)
	}
	rec := synth(t, h, "u", "ok", `not json`)
	if rec.Code != 429 || decode(t, rec)["error"] != "rate_limited" || rec.Header().Get("Retry-After") == "" || v.calls.Load() != 20 {
		t.Fatalf("code=%d verifier calls=%d", rec.Code, v.calls.Load())
	}
	for _, path := range []string{"/healthz", "/v1/config"} {
		r := httptest.NewRecorder()
		h.Routes().ServeHTTP(r, httptest.NewRequest("GET", path, nil))
		if r.Code >= 400 {
			t.Fatalf("protected traffic starved %s: %d", path, r.Code)
		}
	}
}

func TestCallerCannotResetBurstByRotatingOnlyOneIdentifier(t *testing.T) {
	for _, rotateToken := range []bool{false, true} {
		g := NewGuard()
		fixed := time.Now()
		g.now = func() time.Time { return fixed }
		for i := 0; i < 12; i++ {
			token, user := "same-token", fmt.Sprint(i)
			if rotateToken {
				token, user = fmt.Sprint(i), "same-user"
			}
			if !g.allowCaller(token, user) {
				t.Fatal("burst rejected early")
			}
		}
		token, user := "same-token", "another-user"
		if rotateToken {
			token, user = "another-token", "same-user"
		}
		if g.allowCaller(token, user) {
			t.Fatal("rotation bypassed burst limit")
		}
	}
}

func TestCallerMemoryBoundAndActiveEntryRetention(t *testing.T) {
	g := NewGuard()
	g.maxClients = 4
	fixed := time.Now()
	g.now = func() time.Time { return fixed }
	if !g.allowCaller("a", "a") || !g.allowCaller("b", "b") {
		t.Fatal("initial callers")
	}
	release, ok := g.acquire("a", "a")
	if !ok {
		t.Fatal("acquire")
	}
	defer release()
	for i := 0; i < 1000; i++ {
		if g.allowCaller(fmt.Sprint(i), fmt.Sprint(i)) {
			t.Fatal("full cache should fail closed")
		}
	}
	if len(g.clients) != 4 {
		t.Fatal(len(g.clients))
	}
	fixed = fixed.Add(11 * time.Minute)
	if !g.allowCaller("c", "c") {
		t.Fatal("expired inactive entries not reclaimed")
	}
	if _, ok := g.clients[clientKeys("a", "a")[0]]; !ok {
		t.Fatal("evicted active caller")
	}
	release()
	release() // release is idempotent
	if g.active != 0 {
		t.Fatal("active count not restored")
	}
}

type blockingEngine struct {
	entered chan struct{}
	release chan struct{}
}

func (e blockingEngine) Synthesize(ctx context.Context, _ string, _ int, _ voicevox.Options) (voicevox.Result, error) {
	e.entered <- struct{}{}
	select {
	case <-e.release:
		return voicevox.Result{WAV: []byte("RIFF"), Duration: 1}, nil
	case <-ctx.Done():
		return voicevox.Result{}, ctx.Err()
	}
}

func TestConcurrentSynthesisIsRejectedBeforePaidLookup(t *testing.T) {
	h, _, _ := newHandler()
	e := &countEntitlement{}
	h.Entitlement = e
	engine := blockingEngine{make(chan struct{}, 2), make(chan struct{})}
	h.Engine = engine
	done := make(chan *httptest.ResponseRecorder, 2)
	for i := 0; i < 2; i++ {
		go func() { done <- synth(t, h, "u", "ok", `{"text":"あ","speakerId":14}`) }()
	}
	for i := 0; i < 2; i++ {
		select {
		case <-engine.entered:
		case <-time.After(5 * time.Second):
			close(engine.release)
			t.Fatal("engine not reached")
		}
	}
	rec := synth(t, h, "u", "ok", `{"text":"あ","speakerId":14}`)
	close(engine.release)
	for i := 0; i < 2; i++ {
		if r := <-done; r.Code != 200 {
			t.Fatal(r.Body)
		}
	}
	if rec.Code != 429 || decode(t, rec)["error"] != "rate_limited" || e.calls.Load() != 2 {
		t.Fatalf("code=%d calls=%d", rec.Code, e.calls.Load())
	}
	if rec.Header().Get("Cache-Control") != "no-store" || rec.Header().Get("X-Content-Type-Options") != "nosniff" {
		t.Fatal("missing headers")
	}
	if r := synth(t, h, "u", "ok", `{"text":"あ","speakerId":14}`); r.Code != 200 {
		t.Fatal("capacity not released", r.Body)
	}
}
