// gateway は VOICEVOX エンジンの前に置く中継サーバー。
//
// Cloud Run では同じインスタンスに VOICEVOX エンジンをサイドカーとして置き、
// エンジンには 127.0.0.1 からだけ届くようにする（エンジンは認証を持たないため）。
package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"cloud.google.com/go/firestore"
	firebase "firebase.google.com/go/v4"

	"github.com/entaku0818/voiceyourtext-voicevox/internal/api"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/appcheck"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/audio"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/entitlement"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/quota"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/voicevox"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		ReplaceAttr: func(_ []string, a slog.Attr) slog.Attr {
			// Cloud Logging は severity を見て重要度を付ける
			if a.Key == slog.LevelKey {
				a.Key = "severity"
			}
			if a.Key == slog.MessageKey {
				a.Key = "message"
			}
			return a
		},
	}))
	slog.SetDefault(log)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	h := &api.Handler{
		Engine: voicevox.NewClient(env("ENGINE_URL", "http://127.0.0.1:50021")),
		Limits: api.Limits{
			FreeMonthly:     envInt("FREE_MONTHLY_CHARS", 5000),
			PremiumMonthly:  envInt("PREMIUM_MONTHLY_CHARS", 200000),
			MaxRequestChars: envInt("MAX_REQUEST_CHARS", 300),
		},
		Log: log,
	}

	if os.Getenv("LOCAL_DEV") == "1" {
		// 手元で VOICEVOX エンジンだけ動かして試すとき。認証・課金判定・永続化は偽物にする
		log.Warn("LOCAL_DEV: App Check を検証せず、使用量はメモリに持つ")
		h.AppCheck = appcheck.AllowAll{}
		h.Entitlement = entitlement.Static{Premium: map[string]bool{"premium-user": true}}
		h.Quota = &quota.Memory{}
		h.Encoder = audio.FFmpegAAC{}
	} else {
		projectID := mustEnv("GOOGLE_CLOUD_PROJECT")
		app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: projectID})
		if err != nil {
			fatal(log, "firebase init", err)
		}
		ac, err := app.AppCheck(ctx)
		if err != nil {
			fatal(log, "app check init", err)
		}
		fs, err := firestore.NewClient(ctx, projectID)
		if err != nil {
			fatal(log, "firestore init", err)
		}
		defer fs.Close()

		h.AppCheck = appcheck.Verifier{Client: ac, AllowedAppIDs: strings.Split(mustEnv("ALLOWED_APP_IDS"), ",")}
		h.Entitlement = &entitlement.RevenueCat{
			SecretKey:     mustEnv("REVENUECAT_SECRET_KEY"),
			ProjectID:     mustEnv("REVENUECAT_PROJECT_ID"),
			EntitlementID: mustEnv("REVENUECAT_ENTITLEMENT_ID"),
		}
		h.Quota = quota.Firestore{Client: fs}
		h.Encoder = audio.FFmpegAAC{}
	}

	srv := &http.Server{
		Addr:              ":" + env("PORT", "8080"),
		Handler:           h.Routes(),
		ReadHeaderTimeout: 10 * time.Second,
	}
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = srv.Shutdown(shutdown)
	}()

	log.Info("listening", "addr", srv.Addr, "limits", h.Limits)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		fatal(log, "serve", err)
	}
}

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func envInt(key string, fallback int) int {
	v, err := strconv.Atoi(os.Getenv(key))
	if err != nil {
		return fallback
	}
	return v
}

func mustEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		fatal(slog.Default(), "missing env "+key, nil)
	}
	return v
}

func fatal(log *slog.Logger, msg string, err error) {
	log.Error(msg, "err", err)
	os.Exit(1)
}
