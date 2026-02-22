package jobs

import (
	"context"
	"encoding/base64"
	"fmt"
	"log"
	"regexp"
	"strings"
	"unicode/utf8"

	"github.com/entaku0818/voiceyourtext-cloudrun/internal/config"
	texttospeech "google.golang.org/api/texttospeech/v1beta1"
)

// CloudTTSGenerator implements TTSGenerator using Google Cloud TTS v1beta1 API.
type CloudTTSGenerator struct{}

func (g *CloudTTSGenerator) Generate(ctx context.Context, text string, voice *config.VoiceOption, language string) ([]byte, []TTSTimepoint, error) {
	service, err := texttospeech.NewService(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("create TTS service: %w", err)
	}

	ssml, words := buildSSMLWithMarks(text)
	log.Printf("CloudTTSGenerator.Generate: bytes=%d words=%d", len(text), len(words))

	ssmlGender := "FEMALE"
	if voice.Gender == "male" {
		ssmlGender = "MALE"
	}

	req := &texttospeech.SynthesizeSpeechRequest{
		Input: &texttospeech.SynthesisInput{Ssml: ssml},
		Voice: &texttospeech.VoiceSelectionParams{
			LanguageCode: language,
			Name:         voice.WavenetVoice,
			SsmlGender:   ssmlGender,
		},
		AudioConfig:        &texttospeech.AudioConfig{AudioEncoding: "LINEAR16"},
		EnableTimePointing: []string{"SSML_MARK"},
	}

	resp, err := service.Text.Synthesize(req).Context(ctx).Do()
	if err != nil {
		return nil, nil, fmt.Errorf("TTS synthesize: %w", err)
	}

	audioData, err := base64.StdEncoding.DecodeString(resp.AudioContent)
	if err != nil {
		return nil, nil, fmt.Errorf("decode audio base64: %w", err)
	}

	tps := make([]TTSTimepoint, 0, len(resp.Timepoints))
	for _, tp := range resp.Timepoints {
		var idx int
		fmt.Sscanf(tp.MarkName, "%d", &idx)
		if idx < len(words) {
			w := words[idx]
			tps = append(tps, TTSTimepoint{
				MarkName:    fmt.Sprintf("%d:%d:%d", idx, w.startRune, w.endRune),
				TimeSeconds: tp.TimeSeconds,
			})
		}
	}

	return audioData, tps, nil
}

// wordInfo holds byte and rune positions of a word in the original text.
type wordInfo struct {
	startByte int
	endByte   int
	startRune int
	endRune   int
}

var ttsWordRegex = regexp.MustCompile(`[\p{L}\p{N}]+`)

// buildSSMLWithMarks converts plain text to SSML with <mark> tags before each word.
func buildSSMLWithMarks(text string) (string, []wordInfo) {
	matches := ttsWordRegex.FindAllStringIndex(text, -1)
	words := make([]wordInfo, 0, len(matches))
	for _, m := range matches {
		words = append(words, wordInfo{
			startByte: m[0],
			endByte:   m[1],
			startRune: utf8.RuneCountInString(text[:m[0]]),
			endRune:   utf8.RuneCountInString(text[:m[1]]),
		})
	}

	var b strings.Builder
	b.WriteString("<speak>")
	last := 0
	for i, w := range words {
		if w.startByte > last {
			b.WriteString(ttsEscapeXML(text[last:w.startByte]))
		}
		b.WriteString(fmt.Sprintf(`<mark name="%d"/>%s`, i, ttsEscapeXML(text[w.startByte:w.endByte])))
		last = w.endByte
	}
	if last < len(text) {
		b.WriteString(ttsEscapeXML(text[last:]))
	}
	b.WriteString("</speak>")
	return b.String(), words
}

func ttsEscapeXML(s string) string {
	s = strings.ReplaceAll(s, "&", "&amp;")
	s = strings.ReplaceAll(s, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	s = strings.ReplaceAll(s, "'", "&apos;")
	s = strings.ReplaceAll(s, `"`, "&quot;")
	return s
}
