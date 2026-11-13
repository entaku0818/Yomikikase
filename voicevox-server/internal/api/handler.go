// Package api はアプリから呼ばれる HTTP エンドポイント。
//
// VOICEVOX エンジンは認証を持たないので外に出さず、この中継だけを公開する。中継は
//   - Firebase App Check で本物のアプリからの呼び出しかを確かめ
//   - RevenueCat でプレミアム会員かを判定し
//   - 利用者ごとの月の文字数を数えて上限を守り
//   - 許可リストにある声だけを合成する。
package api

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/entaku0818/voiceyourtext-voicevox/internal/audio"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/entitlement"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/policy"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/quota"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/voicevox"
)

// AppCheckVerifier は X-Firebase-AppCheck のトークンを検証する。
type AppCheckVerifier interface {
	Verify(ctx context.Context, token string) error
}

// Synthesizer は VOICEVOX エンジン。
type Synthesizer interface {
	Synthesize(ctx context.Context, text string, speakerID int, opts voicevox.Options) (voicevox.Result, error)
}

// Handler は依存をまとめたもの。
type Handler struct {
	AppCheck    AppCheckVerifier
	Entitlement entitlement.Checker
	Quota       quota.Store
	Engine      Synthesizer
	Encoder     audio.Encoder
	Policy      policy.Source
	Now         func() time.Time
	Log         *slog.Logger
	Guard       *Guard
	guardOnce   sync.Once
}

// Routes は http.Handler を返す。
func (h *Handler) Routes() http.Handler {
	h.guardOnce.Do(func() {
		if h.Guard == nil {
			h.Guard = NewGuard()
		}
	})
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) })
	mux.HandleFunc("GET /v1/voices", h.voices)
	mux.HandleFunc("GET /v1/config", h.config)
	mux.HandleFunc("GET /v1/quota", h.authorized(h.quota))
	mux.HandleFunc("POST /v1/synthesize", h.authorized(h.synthesize))
	return h.guarded(mux)
}

type caller struct {
	userID  string
	premium bool
	limit   int
	policy  policy.Policy
	input   *synthesisInput
}

type ctxKey struct{}

// RevenueCat の App User ID（匿名は $RCAnonymousID:xxxx）に使われる文字だけを許す。
var userIDPattern = regexp.MustCompile(`^[A-Za-z0-9$:_\-.]{1,128}$`)

func (h *Handler) authorized(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := r.Header.Get("X-Firebase-AppCheck")
		if token == "" {
			writeError(w, http.StatusUnauthorized, "app_check_missing", "App Check トークンがありません")
			return
		}
		if len(token) > 8192 {
			writeError(w, http.StatusUnauthorized, "app_check_invalid", "App Check トークンを確認できませんでした")
			return
		}
		if err := h.AppCheck.Verify(r.Context(), token); err != nil {
			writeError(w, http.StatusUnauthorized, "app_check_invalid", "App Check トークンを確認できませんでした")
			return
		}
		userID := r.Header.Get("X-User-ID")
		if !userIDPattern.MatchString(userID) {
			writeError(w, http.StatusBadRequest, "user_id_invalid", "X-User-ID が不正です")
			return
		}
		if !h.Guard.allowCaller(token, userID) {
			rejectBusy(w)
			return
		}
		p, err := h.loadPolicy(r.Context())
		if err != nil {
			h.logger().Error("policy unavailable", "err", err)
			writeError(w, http.StatusServiceUnavailable, "policy_unavailable", "読み上げの設定を取得できませんでした")
			return
		}
		var input *synthesisInput
		if r.URL.Path == "/v1/synthesize" {
			input = readSynthesis(w, r, p)
			if input == nil {
				return
			}
			release, ok := h.Guard.acquire(token, userID)
			if !ok {
				rejectBusy(w)
				return
			}
			defer release()
		}
		premium, err := h.Entitlement.IsPremium(r.Context(), userID)
		if err != nil {
			h.logger().Error("entitlement check failed", "err", err)
			premium = false
		}
		c := caller{userID: userID, premium: premium, limit: p.Voicevox.FreeMonthly, policy: p, input: input}
		if premium {
			c.limit = p.Voicevox.PremiumMonthly
		}
		next(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, c)))
	}
}

func callerFrom(ctx context.Context) caller {
	c, _ := ctx.Value(ctxKey{}).(caller)
	return c
}

func (h *Handler) voices(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	p, err := h.loadPolicy(r.Context())
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "policy_unavailable", "音声の一覧を取得できませんでした")
		return
	}
	writeJSON(w, http.StatusOK, p.Catalog.Public(p.Revision, p.Voicevox.Enabled))
}

type usageResponse struct {
	PolicyRevision  string    `json:"policyRevision"`
	MaxRequestChars int       `json:"maxRequestChars"`
	Enabled         bool      `json:"enabled"`
	Plan            string    `json:"plan"`
	Used            int       `json:"used"`
	Limit           int       `json:"limit"`
	Remaining       int       `json:"remaining"`
	ResetAt         time.Time `json:"resetAt"`
}

func newUsage(c caller, u quota.Usage) usageResponse {
	plan := "free"
	if c.premium {
		plan = "premium"
	}
	remaining := u.Limit - u.Used
	if remaining < 0 {
		remaining = 0
	}
	return usageResponse{PolicyRevision: c.policy.Revision, MaxRequestChars: c.policy.Voicevox.MaxRequestChars, Enabled: c.policy.Voicevox.Enabled, Plan: plan, Used: u.Used, Limit: u.Limit, Remaining: remaining, ResetAt: u.ResetAt}
}

func (h *Handler) quota(w http.ResponseWriter, r *http.Request) {
	c := callerFrom(r.Context())
	u, err := h.Quota.Get(r.Context(), c.userID, c.limit, h.now())
	if err != nil {
		h.logger().Error("quota get failed", "err", err)
		writeError(w, http.StatusServiceUnavailable, "quota_unavailable", "利用状況を取得できませんでした")
		return
	}
	writeJSON(w, http.StatusOK, newUsage(c, u))
}

type synthesizeRequest struct {
	Text       string  `json:"text"`
	SpeakerID  int     `json:"speakerId"`
	SpeedScale float64 `json:"speedScale"`
	PitchScale float64 `json:"pitchScale"`
}

type synthesizeResponse struct {
	Audio    string            `json:"audio"`
	Format   string            `json:"format"`
	Duration float64           `json:"duration"`
	Phrases  []voicevox.Phrase `json:"phrases"`
	Usage    usageResponse     `json:"usage"`
}

// CountChars は上限に数える文字数。前後の空白は数えない。
func CountChars(text string) int {
	return utf8.RuneCountInString(strings.TrimSpace(text))
}

func (h *Handler) synthesize(w http.ResponseWriter, r *http.Request) {
	c := callerFrom(r.Context())

	req, text, chars := c.input.request, c.input.text, c.input.chars

	opts := voicevox.Options{
		SpeedScale: clamp(req.SpeedScale, 0.5, 2.0),
		PitchScale: clamp(req.PitchScale, -0.15, 0.15),
	}

	now := h.now()
	usage, err := h.Quota.Reserve(r.Context(), c.userID, chars, c.limit, now)
	if errors.Is(err, quota.ErrExceeded) {
		writeJSON(w, http.StatusTooManyRequests, map[string]any{
			"error":   "quota_exceeded",
			"message": "今月の読み上げ文字数の上限に達しました",
			"usage":   newUsage(c, usage),
		})
		return
	}
	if err != nil {
		h.logger().Error("quota reserve failed", "err", err)
		writeError(w, http.StatusServiceUnavailable, "quota_unavailable", "利用状況を確認できませんでした")
		return
	}

	refund := func(reason string, err error) {
		h.logger().Error("synthesize failed", "stage", reason, "err", err, "speaker", req.SpeakerID, "chars", chars)
		// 返却に失敗しても利用者に見える影響は「少し多く数えられる」だけなので、ログに残して続ける
		refundCtx, cancel := context.WithTimeout(context.WithoutCancel(r.Context()), 5*time.Second)
		defer cancel()
		if rerr := h.Quota.Refund(refundCtx, c.userID, chars, now); rerr != nil {
			h.logger().Error("quota refund failed", "err", rerr)
		}
	}

	result, err := h.Engine.Synthesize(r.Context(), text, req.SpeakerID, opts)
	if err != nil {
		refund("engine", err)
		writeError(w, http.StatusBadGateway, "synthesis_failed", "音声を作れませんでした")
		return
	}
	data, format, err := h.Encoder.Encode(r.Context(), result.WAV)
	if err != nil {
		refund("encode", err)
		writeError(w, http.StatusInternalServerError, "encode_failed", "音声を変換できませんでした")
		return
	}

	h.logger().Info("synthesized", "speaker", req.SpeakerID, "chars", chars, "plan", newUsage(c, usage).Plan,
		"duration", result.Duration, "bytes", len(data))
	writeJSON(w, http.StatusOK, synthesizeResponse{
		Audio:    base64.StdEncoding.EncodeToString(data),
		Format:   format,
		Duration: result.Duration,
		Phrases:  result.Phrases,
		Usage:    newUsage(c, usage),
	})
}

type synthesisInput struct {
	request synthesizeRequest
	text    string
	chars   int
}

// Validate the complete body and current policy before any paid lookup or reservation.
func readSynthesis(w http.ResponseWriter, r *http.Request, p policy.Policy) *synthesisInput {
	if !p.Voicevox.Enabled {
		writeError(w, http.StatusServiceUnavailable, "generation_disabled", "音声生成を一時停止しています")
		return nil
	}
	var req synthesizeRequest
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxRequestBytes))
	err := decoder.Decode(&req)
	if err == nil {
		if end := decoder.Decode(new(any)); end != io.EOF {
			err = errors.New("trailing or oversized body")
		}
	}
	if err != nil {
		writeError(w, http.StatusBadRequest, "body_invalid", "リクエストを読めませんでした")
		return nil
	}
	text := strings.TrimSpace(req.Text)
	chars := CountChars(text)
	if chars == 0 {
		writeError(w, http.StatusBadRequest, "text_empty", "読み上げる文章がありません")
		return nil
	}
	if chars > p.Voicevox.MaxRequestChars {
		writeError(w, http.StatusRequestEntityTooLarge, "text_too_long", "1回に送れる文字数を超えています。文ごとに分けて送ってください")
		return nil
	}
	if _, ok := p.Catalog.Find(req.SpeakerID); !ok {
		writeError(w, http.StatusBadRequest, "speaker_not_allowed", "この声は使えません")
		return nil
	}
	return &synthesisInput{req, text, chars}
}

func clamp(v, lo, hi float64) float64 {
	if v == 0 {
		return 0
	}
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

func (h *Handler) now() time.Time {
	if h.Now != nil {
		return h.Now()
	}
	return time.Now()
}

func (h *Handler) logger() *slog.Logger {
	if h.Log != nil {
		return h.Log
	}
	return slog.Default()
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]string{"error": code, "message": message})
}

func (h *Handler) loadPolicy(ctx context.Context) (policy.Policy, error) {
	if h.Policy == nil {
		return policy.Policy{}, errors.New("policy source missing")
	}
	p, err := h.Policy.Load(ctx)
	if err != nil {
		return policy.Policy{}, err
	}
	return p, p.Validate()
}

func (h *Handler) config(w http.ResponseWriter, r *http.Request) {
	p, err := h.loadPolicy(r.Context())
	w.Header().Set("Cache-Control", "no-store")
	if err != nil {
		h.logger().Error("policy unavailable", "err", err)
		writeError(w, http.StatusServiceUnavailable, "policy_unavailable", "読み上げの設定を取得できませんでした")
		return
	}
	writeJSON(w, http.StatusOK, p.Public())
}
