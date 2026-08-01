package config

import (
	"testing"
)

func TestGetVoiceByID(t *testing.T) {
	tests := []struct {
		name     string
		voiceID  string
		wantNil  bool
		wantName string
	}{
		{
			name:     "existing English female voice",
			voiceID:  "en-us-female-a",
			wantNil:  false,
			wantName: "Emma",
		},
		{
			name:     "existing Japanese female voice",
			voiceID:  "ja-jp-female-a",
			wantNil:  false,
			wantName: "あかり",
		},
		{
			name:     "existing Chinese female voice",
			voiceID:  "zh-cn-female-a",
			wantNil:  false,
			wantName: "晓雨",
		},
		{
			name:     "existing Chinese male voice",
			voiceID:  "zh-cn-male-b",
			wantNil:  false,
			wantName: "云扬",
		},
		{
			name:     "existing Portuguese female voice",
			voiceID:  "pt-br-female-a",
			wantNil:  false,
			wantName: "Ana",
		},
		{
			name:     "existing Portuguese male voice",
			voiceID:  "pt-br-male-b",
			wantNil:  false,
			wantName: "Lucas",
		},
		{
			name:     "existing Russian female voice",
			voiceID:  "ru-ru-female-a",
			wantNil:  false,
			wantName: "Анна",
		},
		{
			name:     "existing Russian male voice",
			voiceID:  "ru-ru-male-b",
			wantNil:  false,
			wantName: "Дмитрий",
		},
		{
			name:    "non-existing voice",
			voiceID: "non-existing-voice",
			wantNil: true,
		},
		{
			name:    "empty voice ID",
			voiceID: "",
			wantNil: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := GetVoiceByID(tt.voiceID)
			if tt.wantNil {
				if got != nil {
					t.Errorf("GetVoiceByID(%q) = %v, want nil", tt.voiceID, got)
				}
			} else {
				if got == nil {
					t.Errorf("GetVoiceByID(%q) = nil, want non-nil", tt.voiceID)
				} else if got.Name != tt.wantName {
					t.Errorf("GetVoiceByID(%q).Name = %q, want %q", tt.voiceID, got.Name, tt.wantName)
				}
			}
		})
	}
}

func TestGetVoicesByLanguage(t *testing.T) {
	tests := []struct {
		name         string
		language     string
		wantMinCount int
	}{
		{
			name:         "English US voices",
			language:     "en-US",
			wantMinCount: 1,
		},
		{
			name:         "Japanese voices",
			language:     "ja-JP",
			wantMinCount: 1,
		},
		{
			// 中国語のGoogle Cloud TTS言語コードは cmn-CN（zh-CN ではない）
			name:         "Chinese voices use cmn-CN language code",
			language:     "cmn-CN",
			wantMinCount: 2,
		},
		{
			name:         "Portuguese (Brazil) voices",
			language:     "pt-BR",
			wantMinCount: 2,
		},
		{
			name:         "Russian voices",
			language:     "ru-RU",
			wantMinCount: 2,
		},
		{
			// zh-CN は誤った言語コード（正しくは cmn-CN）なので該当0件であるべき
			name:         "zh-CN is not a valid language code (must be cmn-CN)",
			language:     "zh-CN",
			wantMinCount: 0,
		},
		{
			name:         "non-existing language",
			language:     "xx-XX",
			wantMinCount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := GetVoicesByLanguage(tt.language)
			if len(got) < tt.wantMinCount {
				t.Errorf("GetVoicesByLanguage(%q) returned %d voices, want at least %d", tt.language, len(got), tt.wantMinCount)
			}
			for _, v := range got {
				if v.Language != tt.language {
					t.Errorf("GetVoicesByLanguage(%q) returned voice with language %q", tt.language, v.Language)
				}
			}
		})
	}
}

// TestNewLanguageVoicesConfig は追加言語(zh/pt/ru)の音声IDと言語コードの整合性を厳密に検証する。
// IDのtypoや、zh→cmn-CN(zh-CNではない)のようなGoogle Cloud TTS言語コードの取り違えを検知する。
func TestNewLanguageVoicesConfig(t *testing.T) {
	tests := []struct {
		voiceID      string
		wantLanguage string
	}{
		// 中国語(簡体字): Google Cloud TTS の言語コードは cmn-CN（zh-CN ではない）
		{voiceID: "zh-cn-female-a", wantLanguage: "cmn-CN"},
		{voiceID: "zh-cn-male-b", wantLanguage: "cmn-CN"},
		// ポルトガル語(ブラジル)
		{voiceID: "pt-br-female-a", wantLanguage: "pt-BR"},
		{voiceID: "pt-br-male-b", wantLanguage: "pt-BR"},
		// ロシア語
		{voiceID: "ru-ru-female-a", wantLanguage: "ru-RU"},
		{voiceID: "ru-ru-male-b", wantLanguage: "ru-RU"},
	}

	for _, tt := range tests {
		t.Run(tt.voiceID, func(t *testing.T) {
			v := GetVoiceByID(tt.voiceID)
			if v == nil {
				t.Fatalf("GetVoiceByID(%q) = nil, want voice (ID typo?)", tt.voiceID)
			}
			if v.Language != tt.wantLanguage {
				t.Errorf("voice %q Language = %q, want %q", tt.voiceID, v.Language, tt.wantLanguage)
			}
		})
	}

	// zh-CN は誤った言語コード。該当音声が存在しないこと（正しくは cmn-CN）。
	if got := GetVoicesByLanguage("zh-CN"); len(got) != 0 {
		t.Errorf("GetVoicesByLanguage(\"zh-CN\") = %d voices, want 0 (Chinese must use cmn-CN)", len(got))
	}

	// cmn-CN / pt-BR / ru-RU はそれぞれ2音声(female/male)登録されていること。
	for _, lang := range []string{"cmn-CN", "pt-BR", "ru-RU"} {
		if got := GetVoicesByLanguage(lang); len(got) != 2 {
			t.Errorf("GetVoicesByLanguage(%q) = %d voices, want 2", lang, len(got))
		}
	}
}

func TestGetVoicesByGender(t *testing.T) {
	tests := []struct {
		name         string
		gender       string
		wantMinCount int
	}{
		{
			name:         "female voices",
			gender:       "female",
			wantMinCount: 1,
		},
		{
			name:         "male voices",
			gender:       "male",
			wantMinCount: 1,
		},
		{
			name:         "non-existing gender",
			gender:       "other",
			wantMinCount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := GetVoicesByGender(tt.gender)
			if len(got) < tt.wantMinCount {
				t.Errorf("GetVoicesByGender(%q) returned %d voices, want at least %d", tt.gender, len(got), tt.wantMinCount)
			}
			for _, v := range got {
				if v.Gender != tt.gender {
					t.Errorf("GetVoicesByGender(%q) returned voice with gender %q", tt.gender, v.Gender)
				}
			}
		})
	}
}

func TestVoiceOptionToPublic(t *testing.T) {
	voice := VoiceOption{
		ID:           "test-id",
		Name:         "Test Voice",
		Language:     "en-US",
		Gender:       "female",
		Description:  "Test description",
		WavenetVoice: "en-US-Wavenet-A",
	}

	public := voice.ToPublic()

	if public.ID != voice.ID {
		t.Errorf("ToPublic().ID = %q, want %q", public.ID, voice.ID)
	}
	if public.Name != voice.Name {
		t.Errorf("ToPublic().Name = %q, want %q", public.Name, voice.Name)
	}
	if public.Language != voice.Language {
		t.Errorf("ToPublic().Language = %q, want %q", public.Language, voice.Language)
	}
	if public.Gender != voice.Gender {
		t.Errorf("ToPublic().Gender = %q, want %q", public.Gender, voice.Gender)
	}
	if public.Description != voice.Description {
		t.Errorf("ToPublic().Description = %q, want %q", public.Description, voice.Description)
	}
}

func TestGetPublicVoices(t *testing.T) {
	voices := GetPublicVoices()

	if len(voices) != len(AvailableVoices) {
		t.Errorf("GetPublicVoices() returned %d voices, want %d", len(voices), len(AvailableVoices))
	}

	for i, pv := range voices {
		original := AvailableVoices[i]
		if pv.ID != original.ID {
			t.Errorf("GetPublicVoices()[%d].ID = %q, want %q", i, pv.ID, original.ID)
		}
	}
}

func TestGetPublicVoicesByLanguage(t *testing.T) {
	language := "ja-JP"
	publicVoices := GetPublicVoicesByLanguage(language)
	originalVoices := GetVoicesByLanguage(language)

	if len(publicVoices) != len(originalVoices) {
		t.Errorf("GetPublicVoicesByLanguage(%q) returned %d voices, want %d", language, len(publicVoices), len(originalVoices))
	}

	for _, pv := range publicVoices {
		if pv.Language != language {
			t.Errorf("GetPublicVoicesByLanguage(%q) returned voice with language %q", language, pv.Language)
		}
	}
}

func TestAvailableVoicesHasRequiredFields(t *testing.T) {
	for i, v := range AvailableVoices {
		if v.ID == "" {
			t.Errorf("AvailableVoices[%d] has empty ID", i)
		}
		if v.Name == "" {
			t.Errorf("AvailableVoices[%d] has empty Name", i)
		}
		if v.Language == "" {
			t.Errorf("AvailableVoices[%d] has empty Language", i)
		}
		if v.Gender == "" {
			t.Errorf("AvailableVoices[%d] has empty Gender", i)
		}
		if v.WavenetVoice == "" {
			t.Errorf("AvailableVoices[%d] has empty WavenetVoice", i)
		}
	}
}
