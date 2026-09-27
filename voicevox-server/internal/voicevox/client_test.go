package voicevox

import (
	"context"
	"encoding/binary"
	"encoding/json"
	"math"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
)

func TestPhraseTimingFollowsMoraLengthsAndSpeed(t *testing.T) {
	c1, c2 := 0.05, 0.07
	timing := queryTiming{
		SpeedScale:        2,
		PrePhonemeLength:  0.1,
		PostPhonemeLength: 0.1,
		AccentPhrases: []accentPhrase{
			{Moras: []mora{{Text: "コ", ConsonantLength: &c1, VowelLength: 0.1}, {Text: "ン", VowelLength: 0.1}}, PauseMora: &mora{Text: "、", VowelLength: 0.2}},
			{Moras: []mora{{Text: "ニ", ConsonantLength: &c2, VowelLength: 0.13}}},
		},
	}
	phrases, duration := timing.phrases()
	want := []Phrase{{Kana: "コン", Start: 0.05, End: 0.175}, {Kana: "ニ", Start: 0.275, End: 0.375}}
	if len(phrases) != 2 || phrases[0] != want[0] || phrases[1] != want[1] {
		t.Errorf("phrases = %+v, want %+v", phrases, want)
	}
	if duration != 0.425 {
		t.Errorf("duration = %v, want 0.425", duration)
	}
}

// 実エンジンに対して、計算した長さと実際の WAV の長さが一致することを確かめる。
// VOICEVOX_ENGINE_URL=http://127.0.0.1:50021 go test ./internal/voicevox/ で実行する。
func TestEngineDurationMatchesWAV(t *testing.T) {
	base := os.Getenv("VOICEVOX_ENGINE_URL")
	if base == "" {
		t.Skip("VOICEVOX_ENGINE_URL が未設定")
	}
	c := NewClient(base)
	for _, speed := range []float64{0, 1.5} {
		res, err := c.Synthesize(context.Background(), "2026年9月27日、第3回の会議資料を読み上げます。", 14, Options{SpeedScale: speed})
		if err != nil {
			t.Fatal(err)
		}
		wavSeconds := wavDuration(t, res.WAV)
		if math.Abs(wavSeconds-res.Duration) > 0.05 {
			t.Errorf("speed %v: computed %.3fs, wav %.3fs", speed, res.Duration, wavSeconds)
		}
		last := res.Phrases[len(res.Phrases)-1]
		if last.End > res.Duration || res.Phrases[0].Start <= 0 {
			t.Errorf("speed %v: phrases out of range: %+v (duration %.3f)", speed, res.Phrases, res.Duration)
		}
		b, _ := json.Marshal(res.Phrases)
		t.Logf("speed %v: %.3fs %s", speed, res.Duration, b)
	}
}

func wavDuration(t *testing.T, wav []byte) float64 {
	t.Helper()
	if len(wav) < 44 || string(wav[:4]) != "RIFF" {
		t.Fatal("not a wav")
	}
	byteRate := binary.LittleEndian.Uint32(wav[28:32])
	// data チャンクを探す
	for i := 12; i+8 <= len(wav); {
		id := string(wav[i : i+4])
		size := binary.LittleEndian.Uint32(wav[i+4 : i+8])
		if id == "data" {
			return float64(size) / float64(byteRate)
		}
		i += 8 + int(size)
	}
	t.Fatal("no data chunk")
	return 0
}

// 利用者の文章をログに残さないため、エラーメッセージに文章が入らないこと
func TestErrorsDoNotContainText(t *testing.T) {
	secret := "ひみつの文章"
	// 接続できない（url.Error）
	c := NewClient("http://127.0.0.1:1")
	if _, err := c.Synthesize(context.Background(), secret, 14, Options{}); err == nil || containsText(err.Error(), secret) {
		t.Errorf("connection error leaks text: %v", err)
	}
	// エンジンがエラー本文に入力を含めて返す
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnprocessableEntity)
		_, _ = w.Write([]byte(`{"detail":[{"input":"` + r.URL.Query().Get("text") + `"}]}`))
	}))
	defer srv.Close()
	if _, err := NewClient(srv.URL).Synthesize(context.Background(), secret, 14, Options{}); err == nil || containsText(err.Error(), secret) {
		t.Errorf("engine error leaks text: %v", err)
	}
}

func containsText(msg, text string) bool {
	return strings.Contains(msg, text) || strings.Contains(msg, url.QueryEscape(text))
}
