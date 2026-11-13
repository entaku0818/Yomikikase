package api

import (
	"context"
	"crypto/sha256"
	"net/http"
	"sync"
	"time"

	"golang.org/x/time/rate"
)

const maxRequestBytes = 64 << 10

// Guard is bounded, per-instance backpressure, not proof of a user's identity.
// It deliberately does not trust proxy/IP headers or a caller-supplied user ID alone.
// Scaling, token renewal and process restart are NOT durable quota boundaries.
type Guard struct {
	mu         sync.Mutex
	public     *rate.Limiter
	requests   *rate.Limiter
	clients    map[[32]byte]*clientGuard
	maxClients int
	active     int
	now        func() time.Time
}

type clientGuard struct {
	requests *rate.Limiter
	touched  time.Time
	active   int
}

func NewGuard() *Guard {
	return &Guard{
		public: rate.NewLimiter(5, 20), requests: rate.NewLimiter(10, 20),
		clients: make(map[[32]byte]*clientGuard), maxClients: 4096, now: time.Now,
	}
}

func clientKeys(token, user string) [2][32]byte {
	return [2][32]byte{sha256.Sum256([]byte("token:" + token)), sha256.Sum256([]byte("user:" + user))}
}

func (g *Guard) allowCaller(token, user string) bool {
	g.mu.Lock()
	defer g.mu.Unlock()
	now := g.now()
	keys := clientKeys(token, user)
	// Only evict inactive entries that have had enough time to fully refill.
	if len(g.clients)+2 > g.maxClients {
		for key, c := range g.clients {
			if c.active == 0 && now.Sub(c.touched) > 10*time.Minute {
				delete(g.clients, key)
			}
		}
	}
	for _, key := range keys {
		c := g.clients[key]
		if c == nil {
			if len(g.clients) >= g.maxClients {
				return false
			}
			c = &clientGuard{requests: rate.NewLimiter(2, 12)}
			g.clients[key] = c
		}
		c.touched = now
		if !c.requests.AllowN(now, 1) {
			return false
		}
	}
	return true
}

func (g *Guard) acquire(token, user string) (func(), bool) {
	g.mu.Lock()
	defer g.mu.Unlock()
	keys := clientKeys(token, user)
	if g.active >= 2 {
		return nil, false
	}
	for _, key := range keys {
		if g.clients[key] == nil || g.clients[key].active >= 2 {
			return nil, false
		}
	}
	g.active++
	for _, key := range keys {
		g.clients[key].active++
	}
	var once sync.Once
	return func() {
		once.Do(func() {
			g.mu.Lock()
			defer g.mu.Unlock()
			g.active--
			for _, key := range keys {
				g.clients[key].active--
			}
		})
	}, true
}

func rejectBusy(w http.ResponseWriter) {
	w.Header().Set("Retry-After", "2")
	// Keep distinct from quota_exceeded: old clients must not open a purchase flow.
	writeError(w, http.StatusTooManyRequests, "rate_limited", "アクセスが集中しています。少し待ってからお試しください")
}

func (h *Handler) guarded(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		if r.Method == http.MethodGet && r.URL.Path == "/healthz" {
			next.ServeHTTP(w, r)
			return
		}
		bucket := h.Guard.requests
		if r.URL.Path == "/v1/config" || r.URL.Path == "/v1/voices" {
			bucket = h.Guard.public
		}
		if !bucket.AllowN(h.Guard.now(), 1) {
			rejectBusy(w)
			return
		}
		if r.ContentLength > maxRequestBytes {
			writeError(w, http.StatusRequestEntityTooLarge, "body_too_large", "送信内容が大きすぎます")
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 100*time.Second)
		defer cancel()
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
