package policy

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDecodeRejectsUnsafePolicy(t *testing.T) {
	for _, mutate := range []func(*Policy){
		func(p *Policy) { p.Voicevox.MaxRequestChars = 0 },
		func(p *Policy) { p.Voicevox.FreeMonthly = -1 },
		func(p *Policy) { p.Gemini.Enabled = true },
		func(p *Policy) { p.Gemini.FreeMonthly = 1000 },
		func(p *Policy) { p.Topups[0].Enabled = true },
		func(p *Policy) { p.Topups = append(p.Topups, p.Topups[0]) },
		func(p *Policy) { p.SchemaVersion = 99 },
	} {
		p := Default()
		mutate(&p)
		data, _ := json.Marshal(p)
		if _, err := Decode(data); err == nil {
			t.Fatal("unsafe policy accepted")
		}
	}
	for _, data := range []string{`{}`, string(defaultJSON) + `{}`, strings.Replace(string(defaultJSON), `"revision"`, `"typo"`, 1)} {
		if _, err := Decode([]byte(data)); err == nil {
			t.Fatal("invalid policy accepted")
		}
	}
}

func TestFileReadsChangesAndNeverFallsBack(t *testing.T) {
	path := filepath.Join(t.TempDir(), "policy.json")
	source := File{Path: path}
	if err := os.WriteFile(path, defaultJSON, 0600); err != nil {
		t.Fatal(err)
	}
	first, err := source.Load(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	first.Revision = "next"
	first.Voicevox.PremiumMonthly = 1234
	data, _ := json.Marshal(first)
	if err := os.WriteFile(path, data, 0600); err != nil {
		t.Fatal(err)
	}
	next, err := source.Load(context.Background())
	if err != nil || next.Voicevox.PremiumMonthly != 1234 || next.Revision != "next" {
		t.Fatalf("not refreshed: %v %v", next, err)
	}
	if err := os.WriteFile(path, []byte(`{"broken":true}`), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := source.Load(context.Background()); err == nil {
		t.Fatal("must not reuse stale/default policy")
	}
}

func TestPublicProjectionHidesInternalCostsAndUnreleasedProducts(t *testing.T) {
	data, _ := json.Marshal(Default().Public())
	for _, word := range []string{"gemini", "model", "Budget", "topups", "ProductId"} {
		if strings.Contains(string(data), word) {
			t.Fatalf("private/unreleased field leaked: %s", word)
		}
	}
}
