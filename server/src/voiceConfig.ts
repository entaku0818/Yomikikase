export interface VoiceOption {
  id: string;
  name: string;
  language: string;
  gender: 'male' | 'female';
  description: string;
  wavenetVoice: string;
}

export const availableVoices: VoiceOption[] = [
  // Gemini TTS voices - popular options
  {
    id: "zephyr",
    name: "Zephyr", 
    language: "en-US",
    gender: "female",
    description: "Cheerful and energetic voice",
    wavenetVoice: "Zephyr"
  },
  {
    id: "puck",
    name: "Puck",
    language: "en-US", 
    gender: "male",
    description: "Playful and dynamic voice",
    wavenetVoice: "Puck"
  },
  {
    id: "kore",
    name: "Kore",
    language: "en-US",
    gender: "female", 
    description: "Warm and professional voice",
    wavenetVoice: "Kore"
  },
  {
    id: "charon",
    name: "Charon",
    language: "en-US",
    gender: "male",
    description: "Deep and authoritative voice", 
    wavenetVoice: "Charon"
  },
  {
    id: "fenrir",
    name: "Fenrir",
    language: "en-US",
    gender: "male",
    description: "Strong and confident voice",
    wavenetVoice: "Fenrir"
  },
  // Japanese voices (if supported by Gemini TTS)
  {
    id: "jp-female-1",
    name: "あかり",
    language: "ja-JP",
    gender: "female",
    description: "明るく優しい女性の声",
    wavenetVoice: "Zephyr" // Default to English voice for now
  },
  {
    id: "jp-male-1",
    name: "ひろし",
    language: "ja-JP",
    gender: "male", 
    description: "穏やかな男性の声",
    wavenetVoice: "Puck" // Default to English voice for now
  }
];

export function getVoiceById(voiceId: string): VoiceOption | undefined {
  return availableVoices.find(voice => voice.id === voiceId);
}

export function getVoicesByLanguage(language: string): VoiceOption[] {
  return availableVoices.filter(voice => voice.language === language);
}

export function getVoicesByGender(gender: 'male' | 'female'): VoiceOption[] {
  return availableVoices.filter(voice => voice.gender === gender);
}