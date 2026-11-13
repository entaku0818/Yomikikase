// Package policy owns TTS commercial rules. Apps receive a public projection;
// enforcement always uses the server's validated request snapshot.
package policy

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"regexp"
	"strings"

	"cloud.google.com/go/firestore"
	"github.com/entaku0818/voiceyourtext-voicevox/internal/voices"
)

//go:embed default.json
var defaultJSON []byte

const MaxDocumentBytes = 64 << 10

type Voicevox struct {
	Enabled         bool `json:"enabled"`
	FreeMonthly     int  `json:"freeMonthlyChars"`
	PremiumMonthly  int  `json:"premiumMonthlyChars"`
	MaxRequestChars int  `json:"maxRequestChars"`
}

type Gemini struct {
	Enabled                              bool   `json:"enabled"`
	FreeMonthly                          int    `json:"freeMonthlyChars"`
	PremiumMonthly                       int    `json:"premiumMonthlyChars"`
	MaxRequestChars                      int    `json:"maxRequestChars"`
	MinimumChargeChars                   int    `json:"minimumChargeChars"`
	Model                                string `json:"model"`
	GenerationBudgetMilliJpyPer1000Chars int64  `json:"generationBudgetMilliJpyPer1000Chars"`
	MaxAttempts                          int    `json:"maxAttempts"`
	MaxConcurrentRequestsPerAccount      int    `json:"maxConcurrentRequestsPerAccount"`
}

type Topup struct {
	ID               string `json:"id"`
	Chars            int    `json:"chars"`
	IOSProductID     string `json:"iosProductId"`
	AndroidProductID string `json:"androidProductId"`
	Enabled          bool   `json:"enabled"`
}

type Policy struct {
	Catalog       voices.Catalog `json:"catalog"`
	SchemaVersion int            `json:"schemaVersion"`
	Revision      string         `json:"revision"`
	Voicevox      Voicevox       `json:"voicevox"`
	Gemini        Gemini         `json:"gemini"`
	Topups        []Topup        `json:"topups"`
}

var identifier = regexp.MustCompile(`^[A-Za-z0-9_.:-]{1,128}$`)

func (p Policy) Validate() error {
	if p.SchemaVersion != 1 || !identifier.MatchString(p.Revision) {
		return errors.New("invalid policy schema or revision")
	}
	if err := p.Catalog.Validate(); err != nil {
		return err
	}
	v := p.Voicevox
	if v.FreeMonthly < 0 || v.PremiumMonthly < 0 || v.FreeMonthly > 100000000 || v.PremiumMonthly > 100000000 || v.MaxRequestChars < 1 || v.MaxRequestChars > 4000 {
		return errors.New("invalid voicevox limits")
	}
	g := p.Gemini
	if g.FreeMonthly != 0 || g.PremiumMonthly < 0 || g.PremiumMonthly > 100000000 || g.MaxRequestChars < 1 || g.MaxRequestChars > 1000 || g.MinimumChargeChars < 1 || g.MinimumChargeChars > g.MaxRequestChars || !identifier.MatchString(g.Model) || g.GenerationBudgetMilliJpyPer1000Chars < 1 || g.GenerationBudgetMilliJpyPer1000Chars > 10000000 || g.MaxAttempts < 1 || g.MaxAttempts > 2 || g.MaxConcurrentRequestsPerAccount != 1 {
		return errors.New("invalid gemini policy")
	}
	// The purchase ledger, verified user identity and Gemini generator are not
	// connected yet. Configuration alone must never advertise a working purchase.
	if g.Enabled {
		return errors.New("gemini rollout is not supported by this server version")
	}
	seen := map[string]bool{}
	for _, t := range p.Topups {
		if !identifier.MatchString(t.ID) || seen[t.ID] || t.Chars < 1 || t.Chars > 10000000 {
			return errors.New("invalid or duplicate topup")
		}
		seen[t.ID] = true
		if t.Enabled {
			return errors.New("topup rollout is not supported by this server version")
		}
	}
	return nil
}

func Decode(data []byte) (Policy, error) {
	var p Policy
	if len(data) > MaxDocumentBytes {
		return p, errors.New("policy is too large")
	}
	d := json.NewDecoder(bytes.NewReader(data))
	d.DisallowUnknownFields()
	if err := d.Decode(&p); err != nil {
		return Policy{}, err
	}
	if err := d.Decode(new(any)); err != io.EOF {
		return Policy{}, errors.New("policy contains trailing data")
	}
	if err := p.Validate(); err != nil {
		return Policy{}, err
	}
	return p, nil
}

func Default() Policy {
	p, err := Decode(defaultJSON)
	if err != nil {
		panic(err)
	}
	return p
}

// PublicConfig intentionally excludes provider models, cost budgets and planned
// products. Store prices must come from StoreKit / Play Billing, never this API.
type PublicConfig struct {
	SchemaVersion int      `json:"schemaVersion"`
	Revision      string   `json:"revision"`
	Voicevox      Voicevox `json:"voicevox"`
}

func (p Policy) Public() PublicConfig { return PublicConfig{p.SchemaVersion, p.Revision, p.Voicevox} }

type Source interface {
	Load(context.Context) (Policy, error)
}

type Static struct{ Policy Policy }

func (s Static) Load(context.Context) (Policy, error) { return s.Policy, s.Policy.Validate() }

// File re-reads every request. Replace the file atomically; malformed/missing
// files fail closed instead of silently restoring larger default quotas.
type File struct{ Path string }

func (f File) Load(context.Context) (Policy, error) {
	file, err := os.Open(f.Path)
	if err != nil {
		return Policy{}, err
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, MaxDocumentBytes+1))
	if err != nil {
		return Policy{}, err
	}
	return Decode(data)
}

// Firestore stores a JSON string in the `json` field of `tts_policy/current`. Each request
// reads one complete document, so no cross-instance cache delay is introduced.
// Client Firestore rules must deny access; only the server/admin may write it.
type Firestore struct {
	Client   *firestore.Client
	Document string
}

func (f Firestore) Load(ctx context.Context) (Policy, error) {
	if f.Client == nil || !ValidDocumentPath(f.Document) {
		return Policy{}, errors.New("invalid policy document source")
	}
	snap, err := f.Client.Doc(f.Document).Get(ctx)
	if err != nil {
		return Policy{}, err
	}
	v, err := snap.DataAt("json")
	if err != nil {
		return Policy{}, err
	}
	data, ok := v.(string)
	if !ok {
		return Policy{}, fmt.Errorf("policy json must be a string")
	}
	return Decode([]byte(data))
}

func ValidDocumentPath(path string) bool {
	parts := strings.Split(path, "/")
	if len(parts) < 2 || len(parts)%2 != 0 {
		return false
	}
	for _, part := range parts {
		if part == "" || part == "." || part == ".." {
			return false
		}
	}
	return true
}
