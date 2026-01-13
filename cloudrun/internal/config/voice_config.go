package config

// VoiceOption represents a TTS voice configuration
type VoiceOption struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	Language     string `json:"language"`
	Gender       string `json:"gender"`
	Description  string `json:"description"`
	WavenetVoice string `json:"wavenetVoice,omitempty"`
}

// PublicVoiceOption is the public-facing voice option without wavenetVoice
type PublicVoiceOption struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Language    string `json:"language"`
	Gender      string `json:"gender"`
	Description string `json:"description"`
}

// AvailableVoices contains all available TTS voices
var AvailableVoices = []VoiceOption{
	// English (US) voices
	{
		ID:           "en-us-female-a",
		Name:         "Emma",
		Language:     "en-US",
		Gender:       "female",
		Description:  "Clear American female voice",
		WavenetVoice: "en-US-Wavenet-F",
	},
	{
		ID:           "en-us-male-b",
		Name:         "John",
		Language:     "en-US",
		Gender:       "male",
		Description:  "Professional American male voice",
		WavenetVoice: "en-US-Wavenet-B",
	},
	{
		ID:           "en-us-female-c",
		Name:         "Sarah",
		Language:     "en-US",
		Gender:       "female",
		Description:  "Warm American female voice",
		WavenetVoice: "en-US-Wavenet-C",
	},
	{
		ID:           "en-us-male-d",
		Name:         "Mike",
		Language:     "en-US",
		Gender:       "male",
		Description:  "Deep American male voice",
		WavenetVoice: "en-US-Wavenet-D",
	},
	// Japanese voices - Wavenet
	{
		ID:           "ja-jp-female-a",
		Name:         "あかり",
		Language:     "ja-JP",
		Gender:       "female",
		Description:  "明るく優しい女性の声",
		WavenetVoice: "ja-JP-Wavenet-A",
	},
	{
		ID:           "ja-jp-female-b",
		Name:         "さくら",
		Language:     "ja-JP",
		Gender:       "female",
		Description:  "落ち着いた女性の声",
		WavenetVoice: "ja-JP-Wavenet-B",
	},
	{
		ID:           "ja-jp-male-c",
		Name:         "ひろし",
		Language:     "ja-JP",
		Gender:       "male",
		Description:  "穏やかな男性の声",
		WavenetVoice: "ja-JP-Wavenet-C",
	},
	{
		ID:           "ja-jp-male-d",
		Name:         "けんじ",
		Language:     "ja-JP",
		Gender:       "male",
		Description:  "力強い男性の声",
		WavenetVoice: "ja-JP-Wavenet-D",
	},
	// Japanese voices - Neural2 (higher quality)
	{
		ID:           "ja-jp-neural-female-b",
		Name:         "みさき",
		Language:     "ja-JP",
		Gender:       "female",
		Description:  "自然で滑らかな女性の声 (Neural2)",
		WavenetVoice: "ja-JP-Neural2-B",
	},
	{
		ID:           "ja-jp-neural-female-c",
		Name:         "ゆい",
		Language:     "ja-JP",
		Gender:       "female",
		Description:  "親しみやすい女性の声 (Neural2)",
		WavenetVoice: "ja-JP-Neural2-C",
	},
	{
		ID:           "ja-jp-neural-male-d",
		Name:         "たくや",
		Language:     "ja-JP",
		Gender:       "male",
		Description:  "クリアな男性の声 (Neural2)",
		WavenetVoice: "ja-JP-Neural2-D",
	},
	// German voices
	{
		ID:           "de-de-female-a",
		Name:         "Anna",
		Language:     "de-DE",
		Gender:       "female",
		Description:  "Klare deutsche Frauenstimme",
		WavenetVoice: "de-DE-Wavenet-A",
	},
	{
		ID:           "de-de-male-b",
		Name:         "Hans",
		Language:     "de-DE",
		Gender:       "male",
		Description:  "Professionelle deutsche Männerstimme",
		WavenetVoice: "de-DE-Wavenet-B",
	},
	// Spanish voices
	{
		ID:           "es-es-female-a",
		Name:         "María",
		Language:     "es-ES",
		Gender:       "female",
		Description:  "Voz femenina española clara",
		WavenetVoice: "es-ES-Wavenet-C",
	},
	{
		ID:           "es-es-male-b",
		Name:         "Carlos",
		Language:     "es-ES",
		Gender:       "male",
		Description:  "Voz masculina española profesional",
		WavenetVoice: "es-ES-Wavenet-B",
	},
	// French voices
	{
		ID:           "fr-fr-female-a",
		Name:         "Sophie",
		Language:     "fr-FR",
		Gender:       "female",
		Description:  "Voix féminine française claire",
		WavenetVoice: "fr-FR-Wavenet-A",
	},
	{
		ID:           "fr-fr-male-b",
		Name:         "Pierre",
		Language:     "fr-FR",
		Gender:       "male",
		Description:  "Voix masculine française professionnelle",
		WavenetVoice: "fr-FR-Wavenet-B",
	},
	// Italian voices
	{
		ID:           "it-it-female-a",
		Name:         "Giulia",
		Language:     "it-IT",
		Gender:       "female",
		Description:  "Voce femminile italiana chiara",
		WavenetVoice: "it-IT-Wavenet-A",
	},
	{
		ID:           "it-it-male-b",
		Name:         "Marco",
		Language:     "it-IT",
		Gender:       "male",
		Description:  "Voce maschile italiana professionale",
		WavenetVoice: "it-IT-Wavenet-C",
	},
	// Korean voices
	{
		ID:           "ko-kr-female-a",
		Name:         "지현",
		Language:     "ko-KR",
		Gender:       "female",
		Description:  "밝고 친근한 여성 목소리",
		WavenetVoice: "ko-KR-Wavenet-A",
	},
	{
		ID:           "ko-kr-male-b",
		Name:         "민수",
		Language:     "ko-KR",
		Gender:       "male",
		Description:  "차분한 남성 목소리",
		WavenetVoice: "ko-KR-Wavenet-C",
	},
	// Turkish voices
	{
		ID:           "tr-tr-female-a",
		Name:         "Ayşe",
		Language:     "tr-TR",
		Gender:       "female",
		Description:  "Net Türkçe kadın sesi",
		WavenetVoice: "tr-TR-Wavenet-A",
	},
	{
		ID:           "tr-tr-male-b",
		Name:         "Mehmet",
		Language:     "tr-TR",
		Gender:       "male",
		Description:  "Profesyonel Türkçe erkek sesi",
		WavenetVoice: "tr-TR-Wavenet-B",
	},
	// Vietnamese voices
	{
		ID:           "vi-vn-female-a",
		Name:         "Linh",
		Language:     "vi-VN",
		Gender:       "female",
		Description:  "Giọng nữ Việt Nam rõ ràng",
		WavenetVoice: "vi-VN-Wavenet-A",
	},
	{
		ID:           "vi-vn-male-b",
		Name:         "Minh",
		Language:     "vi-VN",
		Gender:       "male",
		Description:  "Giọng nam Việt Nam chuyên nghiệp",
		WavenetVoice: "vi-VN-Wavenet-B",
	},
	// Thai voices (Standard only, no Wavenet)
	{
		ID:           "th-th-female-a",
		Name:         "นภา",
		Language:     "th-TH",
		Gender:       "female",
		Description:  "เสียงผู้หญิงไทยที่ชัดเจน",
		WavenetVoice: "th-TH-Standard-A",
	},
}

// GetVoiceByID returns a voice by its ID
func GetVoiceByID(voiceID string) *VoiceOption {
	for _, v := range AvailableVoices {
		if v.ID == voiceID {
			return &v
		}
	}
	return nil
}

// GetVoicesByLanguage returns voices filtered by language
func GetVoicesByLanguage(language string) []VoiceOption {
	var filtered []VoiceOption
	for _, v := range AvailableVoices {
		if v.Language == language {
			filtered = append(filtered, v)
		}
	}
	return filtered
}

// GetVoicesByGender returns voices filtered by gender
func GetVoicesByGender(gender string) []VoiceOption {
	var filtered []VoiceOption
	for _, v := range AvailableVoices {
		if v.Gender == gender {
			filtered = append(filtered, v)
		}
	}
	return filtered
}

// ToPublic converts a VoiceOption to PublicVoiceOption (hides wavenetVoice)
func (v *VoiceOption) ToPublic() PublicVoiceOption {
	return PublicVoiceOption{
		ID:          v.ID,
		Name:        v.Name,
		Language:    v.Language,
		Gender:      v.Gender,
		Description: v.Description,
	}
}

// GetPublicVoices returns all voices as public options
func GetPublicVoices() []PublicVoiceOption {
	result := make([]PublicVoiceOption, len(AvailableVoices))
	for i, v := range AvailableVoices {
		result[i] = v.ToPublic()
	}
	return result
}

// GetPublicVoicesByLanguage returns filtered voices as public options
func GetPublicVoicesByLanguage(language string) []PublicVoiceOption {
	voices := GetVoicesByLanguage(language)
	result := make([]PublicVoiceOption, len(voices))
	for i, v := range voices {
		result[i] = v.ToPublic()
	}
	return result
}
