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
	"strings"
	"syscall"
	"time"

	"cloud.google.com/go/firestore"
	firebase "firebase.google.com/go/v4"

	"github.com/entaku0818/voiceyourtext-voicevox/internal/api"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/appcheck"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/audio"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/entitlement"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/policy"
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

	if os.Getenv("LOCAL_DEV") == "1" && os.Getenv("K_SERVICE") != "" {
		fatal(log, "LOCAL_DEV must never run on Cloud Run", nil)
	}

	h := &api.Handler{
		Engine: voicevox.NewClient(env("ENGINE_URL", "http://127.0.0.1:50021")),
		Policy: policy.Static{Policy: policy.Default()},
		Log:    log,
	}

	policyFile := os.Getenv("TTS_POLICY_FILE")
	policyDocument := os.Getenv("TTS_POLICY_DOCUMENT")
	if policyFile != "" && policyDocument != "" {
		fatal(log, "set only one policy source", nil)
	}
	if policyFile != "" {
		h.Policy = policy.File{Path: policyFile}
	}
	if policyDocument != "" && os.Getenv("LOCAL_DEV") == "1" {
		fatal(log, "Firestore policy requires production authentication", nil)
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
			// Secret Manager に改行付きで登録されると Authorization ヘッダーが不正になるので落とす
			SecretKey:     strings.TrimSpace(mustEnv("REVENUECAT_SECRET_KEY")),
			ProjectID:     mustEnv("REVENUECAT_PROJECT_ID"),
			EntitlementID: mustEnv("REVENUECAT_ENTITLEMENT_ID"),
		}
		h.Quota = quota.Firestore{Client: fs}
		if policyDocument != "" {
			h.Policy = policy.Firestore{Client: fs, Document: policyDocument}
		}
		h.Encoder = audio.FFmpegAAC{}
	}

	initialPolicy, err := h.Policy.Load(ctx)
	if err != nil {
		fatal(log, "invalid initial policy", err)
	}

	// 最初の利用者が声の読み込みを待たないよう、起動したら裏で6声を読み込んでおく
	go warmUp(ctx, log, voicevox.NewClient(env("ENGINE_URL", "http://127.0.0.1:50021")), initialPolicy)

	srv := &http.Server{
		Addr:              ":" + env("PORT", "8080"),
		Handler:           h.Routes(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      115 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    16 << 10,
	}
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = srv.Shutdown(shutdown)
	}()

	log.Info("listening", "addr", srv.Addr, "policyRevision", initialPolicy.Revision)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		fatal(log, "serve", err)
	}
}

// warmUp はエンジンの起動を待ってから、許可リストの声を全部読み込む。
func warmUp(ctx context.Context, log *slog.Logger, engine *voicevox.Client, p policy.Policy) {
	if !p.Voicevox.Enabled {
		return
	}
	start := time.Now()
	for engine.Ready(ctx) != nil {
		select {
		case <-ctx.Done():
			return
		case <-time.After(time.Second):
		}
	}
	for _, v := range p.Catalog.Voices {
		if !v.Enabled {
			continue
		}
		t := time.Now()
		if err := engine.InitializeSpeaker(ctx, v.SpeakerID); err != nil {
			log.Warn("warm up failed", "speaker", v.SpeakerID, "err", err)
			continue
		}
		log.Info("speaker loaded", "speaker", v.SpeakerID, "seconds", time.Since(t).Seconds())
	}
	log.Info("warm up done", "seconds", time.Since(start).Seconds())
}

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
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
