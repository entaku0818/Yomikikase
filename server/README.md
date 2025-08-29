# VoiceYourText Firebase Functions

Firebase Functions for the VoiceYourText app, providing Gemini AI integration for audio generation.

## Setup

1. Install dependencies:
```bash
cd server
npm install
```

2. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your API keys
```

3. Configure Firebase:
```bash
# Edit .firebaserc with your project ID
# Set up Firebase Storage bucket in Firebase Console
firebase functions:config:set gemini.api_key="your-api-key"
```

4. Build the project:
```bash
npm run build
```

## Available Functions

### `generateAudio`
Basic audio generation using Gemini AI for text processing.

**Endpoint:** `POST /generateAudio`

**Request Body:**
```json
{
  "text": "こんにちは、世界！",
  "language": "ja-JP"
}
```

**Response:**
```json
{
  "success": true,
  "processedText": "Enhanced text from Gemini",
  "originalText": "こんにちは、世界！",
  "language": "ja-JP",
  "message": "Audio generation completed"
}
```

### `generateAudioWithTTS`
Real audio generation using Gemini 2.0 Flash TTS with voice selection.

**Endpoint:** `POST /generateAudioWithTTS`

**Request Body:**
```json
{
  "text": "Hello, how are you today?",
  "language": "en-US",
  "voiceId": "zephyr",
  "style": "cheerfully"
}
```

**Response:**
```json
{
  "success": true,
  "originalText": "Hello, how are you today?",
  "language": "en-US",
  "voice": {
    "id": "zephyr",
    "name": "Zephyr",
    "language": "en-US",
    "gender": "female",
    "description": "Cheerful and energetic voice"
  },
  "style": "cheerfully",
  "audioUrl": "https://storage.googleapis.com/your-bucket-name/audio/zephyr_1234567890_uuid.wav",
  "filename": "audio/zephyr_1234567890_uuid.wav",
  "mimeType": "audio/wav",
  "message": "Audio generated and saved successfully"
}
```

### `getVoices`
Get list of available voices for TTS generation.

**Endpoint:** `GET /getVoices` or `GET /getVoices?language=en-US`

**Response:**
```json
{
  "success": true,
  "voices": [
    {
      "id": "zephyr",
      "name": "Zephyr",
      "language": "en-US", 
      "gender": "female",
      "description": "Cheerful and energetic voice"
    }
  ]
}
```

## Development

### Local Testing
```bash
npm run serve
```

### Run Tests
```bash
npm test
```

### Deploy to Firebase
```bash
npm run deploy
```

## Environment Variables

- `GEMINI_API_KEY`: Your Google Gemini API key
- `GOOGLE_CLOUD_PROJECT_ID`: Your Google Cloud project ID
- `FIREBASE_PROJECT_ID`: Your Firebase project ID

## Architecture

The functions are built with:
- **Firebase Functions v2**: Serverless cloud functions
- **Google Gemini AI**: Text processing and enhancement
- **TypeScript**: Type-safe development
- **Mocha**: Unit testing framework

## Error Handling

All functions include comprehensive error handling:
- Input validation
- API error handling
- Structured error responses
- Logging for debugging