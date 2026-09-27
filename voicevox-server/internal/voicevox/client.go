// Package voicevox は、同じインスタンス内で動く VOICEVOX エンジン（サイドカー）を呼ぶ。
package voicevox

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"time"
)

// Client は VOICEVOX エンジンの HTTP API クライアント。
type Client struct {
	BaseURL string
	HTTP    *http.Client
}

// NewClient は baseURL（例: http://127.0.0.1:50021）のエンジンを呼ぶクライアントを作る。
func NewClient(baseURL string) *Client {
	return &Client{BaseURL: baseURL, HTTP: &http.Client{Timeout: 120 * time.Second}}
}

// Options は読み上げの調整値。0 はエンジンの既定値を使う。
type Options struct {
	SpeedScale float64
	PitchScale float64
}

// Phrase はアクセント句1つ分の読みと再生位置（秒）。アプリの文字ハイライトに使う。
type Phrase struct {
	Kana  string  `json:"kana"`
	Start float64 `json:"start"`
	End   float64 `json:"end"`
}

// Result は合成結果。
type Result struct {
	WAV      []byte
	Duration float64
	Phrases  []Phrase
}

// Synthesize は text を speakerID の声で WAV にする。
func (c *Client) Synthesize(ctx context.Context, text string, speakerID int, opts Options) (Result, error) {
	q := url.Values{"text": {text}, "speaker": {strconv.Itoa(speakerID)}}
	rawQuery, err := c.post(ctx, "/audio_query?"+q.Encode(), nil)
	if err != nil {
		return Result{}, fmt.Errorf("audio_query: %w", err)
	}

	var query audioQuery
	if err := json.Unmarshal(rawQuery, &query.fields); err != nil {
		return Result{}, fmt.Errorf("decode audio_query: %w", err)
	}
	if err := json.Unmarshal(rawQuery, &query.timing); err != nil {
		return Result{}, fmt.Errorf("decode audio_query timing: %w", err)
	}
	if opts.SpeedScale > 0 {
		query.fields["speedScale"] = opts.SpeedScale
		query.timing.SpeedScale = opts.SpeedScale
	}
	if opts.PitchScale != 0 {
		query.fields["pitchScale"] = opts.PitchScale
	}
	body, err := json.Marshal(query.fields)
	if err != nil {
		return Result{}, err
	}

	wav, err := c.post(ctx, "/synthesis?"+url.Values{"speaker": {strconv.Itoa(speakerID)}}.Encode(), body)
	if err != nil {
		return Result{}, fmt.Errorf("synthesis: %w", err)
	}
	phrases, duration := query.timing.phrases()
	return Result{WAV: wav, Duration: duration, Phrases: phrases}, nil
}

// Ready はエンジンが応答するかを返す。
func (c *Client) Ready(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.BaseURL+"/version", nil)
	if err != nil {
		return err
	}
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("engine returned %d", resp.StatusCode)
	}
	return nil
}

func (c *Client) post(ctx context.Context, path string, body []byte) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.BaseURL+path, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("engine returned %d: %s", resp.StatusCode, truncate(data, 200))
	}
	return data, nil
}

// audioQuery は audio_query のレスポンス。fields はそのまま synthesis に渡し、timing は再生位置の計算に使う。
type audioQuery struct {
	fields map[string]any
	timing queryTiming
}

type queryTiming struct {
	AccentPhrases     []accentPhrase `json:"accent_phrases"`
	SpeedScale        float64        `json:"speedScale"`
	PrePhonemeLength  float64        `json:"prePhonemeLength"`
	PostPhonemeLength float64        `json:"postPhonemeLength"`
}

type accentPhrase struct {
	Moras     []mora `json:"moras"`
	PauseMora *mora  `json:"pause_mora"`
}

type mora struct {
	Text            string   `json:"text"`
	ConsonantLength *float64 `json:"consonant_length"`
	VowelLength     float64  `json:"vowel_length"`
}

func (m mora) length() float64 {
	l := m.VowelLength
	if m.ConsonantLength != nil {
		l += *m.ConsonantLength
	}
	return l
}

// phrases は各アクセント句の開始・終了秒と全体の長さを返す。
// VOICEVOX は前後の無音と各モーラ長を speedScale で割った長さで音声を作る。
func (t queryTiming) phrases() ([]Phrase, float64) {
	speed := t.SpeedScale
	if speed <= 0 {
		speed = 1
	}
	cursor := t.PrePhonemeLength / speed
	out := make([]Phrase, 0, len(t.AccentPhrases))
	for _, ap := range t.AccentPhrases {
		start := cursor
		kana := ""
		for _, m := range ap.Moras {
			cursor += m.length() / speed
			kana += m.Text
		}
		out = append(out, Phrase{Kana: kana, Start: round3(start), End: round3(cursor)})
		if ap.PauseMora != nil {
			cursor += ap.PauseMora.length() / speed
		}
	}
	cursor += t.PostPhonemeLength / speed
	return out, round3(cursor)
}

func round3(v float64) float64 {
	return float64(int64(v*1000+0.5)) / 1000
}

func truncate(b []byte, n int) string {
	if len(b) > n {
		return string(b[:n])
	}
	return string(b)
}
