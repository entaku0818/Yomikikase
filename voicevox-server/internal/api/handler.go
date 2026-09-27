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
	"log/slog"
	"net/http"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/entaku0818/voiceyourtext-voicevox/internal/audio"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/entitlement"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/quota"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/voices"
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

// Limits は月の上限と1回あたりの文字数。
type Limits struct {
	FreeMonthly    int
	PremiumMonthly int
	// MaxRequestChars は1回で合成できる最大文字数。アプリは文ごとに分けて送る。
	MaxRequestChars int
}

// Handler は依存をまとめたもの。
type Handler struct {
	AppCheck    AppCheckVerifier
	Entitlement entitlement.Checker
	Quota       quota.Store
	Engine      Synthesizer
	Encoder     audio.Encoder
	Limits      Limits
	Now         func() time.Time
	Log         *slog.Logger
}

// Routes は http.Handler を返す。
func (h *Handler) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) })
	mux.HandleFunc("GET /v1/voices", h.voices)
	mux.HandleFunc("GET /v1/quota", h.authorized(h.quota))
	mux.HandleFunc("POST /v1/synthesize", h.authorized(h.synthesize))
	return mux
}

type caller struct {
	userID  string
	premium bool
	limit   int
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
		if err := h.AppCheck.Verify(r.Context(), token); err != nil {
			h.logger().Warn("app check rejected", "err", err)
			writeError(w, http.StatusUnauthorized, "app_check_invalid", "App Check トークンを確認できませんでした")
			return
		}
		userID := r.Header.Get("X-User-ID")
		if !userIDPattern.MatchString(userID) {
			writeError(w, http.StatusBadRequest, "user_id_invalid", "X-User-ID が不正です")
			return
		}
		premium, err := h.Entitlement.IsPremium(r.Context(), userID)
		if err != nil {
			// RevenueCat が落ちていても読み上げを止めないよう、無料枠で続ける
			h.logger().Error("entitlement check failed", "err", err)
			premium = false
		}
		c := caller{userID: userID, premium: premium, limit: h.Limits.FreeMonthly}
		if premium {
			c.limit = h.Limits.PremiumMonthly
		}
		next(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, c)))
	}
}

func callerFrom(ctx context.Context) caller {
	c, _ := ctx.Value(ctxKey{}).(caller)
	return c
}

func (h *Handler) voices(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"voices": voices.All})
}

type usageResponse struct {
	Plan      string    `json:"plan"`
	Used      int       `json:"used"`
	Limit     int       `json:"limit"`
	Remaining int       `json:"remaining"`
	ResetAt   time.Time `json:"resetAt"`
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
	return usageResponse{Plan: plan, Used: u.Used, Limit: u.Limit, Remaining: remaining, ResetAt: u.ResetAt}
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

	var req synthesizeRequest
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 64<<10)).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "body_invalid", "リクエストを読めませんでした")
		return
	}
	text := strings.TrimSpace(req.Text)
	chars := CountChars(text)
	if chars == 0 {
		writeError(w, http.StatusBadRequest, "text_empty", "読み上げる文章がありません")
		return
	}
	if chars > h.Limits.MaxRequestChars {
		writeError(w, http.StatusRequestEntityTooLarge, "text_too_long", "1回に送れる文字数を超えています。文ごとに分けて送ってください")
		return
	}
	if _, ok := voices.Find(req.SpeakerID); !ok {
		writeError(w, http.StatusBadRequest, "speaker_not_allowed", "この声は使えません")
		return
	}
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
		if rerr := h.Quota.Refund(context.WithoutCancel(r.Context()), c.userID, chars, now); rerr != nil {
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
