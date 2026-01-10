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
	// Japanese voices
	{
		ID:           "ja-jp-female-a",
		Name:         "あかり",
		Language:     "ja-JP",
		Gender:       "female",
		Description:  "明るく優しい女性の声",
		WavenetVoice: "ja-JP-Wavenet-A",
	},
	{
		ID:           "ja-jp-male-b",
		Name:         "ひろし",
		Language:     "ja-JP",
		Gender:       "male",
		Description:  "穏やかな男性の声",
		WavenetVoice: "ja-JP-Wavenet-C",
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
