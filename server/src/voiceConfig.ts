export interface VoiceOption {
  id: string;
  name: string;
  language: string;
  gender: 'male' | 'female';
  description: string;
  wavenetVoice: string;
}

export const availableVoices: VoiceOption[] = [
  // Google Cloud TTS voices
  {
    id: "en-us-female-a",
    name: "Emma", 
    language: "en-US",
    gender: "female",
    description: "Clear American female voice",
    wavenetVoice: "en-US-Wavenet-A"
  },
  {
    id: "en-us-male-b",
    name: "John",
    language: "en-US", 
    gender: "male",
    description: "Professional American male voice",
    wavenetVoice: "en-US-Wavenet-B"
  },
  {
    id: "en-us-female-c",
    name: "Sarah",
    language: "en-US",
    gender: "female", 
    description: "Warm American female voice",
    wavenetVoice: "en-US-Wavenet-C"
  },
  {
    id: "en-us-male-d",
    name: "Mike",
    language: "en-US",
    gender: "male",
    description: "Deep American male voice", 
    wavenetVoice: "en-US-Wavenet-D"
  },
  // Japanese voices
  {
    id: "ja-jp-female-a",
    name: "あかり",
    language: "ja-JP",
    gender: "female",
    description: "明るく優しい女性の声",
    wavenetVoice: "ja-JP-Wavenet-A"
  },
  {
    id: "ja-jp-male-b",
    name: "ひろし",
    language: "ja-JP",
    gender: "male", 
    description: "穏やかな男性の声",
    wavenetVoice: "ja-JP-Wavenet-C"
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