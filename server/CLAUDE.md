# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with the Firebase Functions server code in this repository.

## Project Overview

This is the Firebase Functions backend for the VoiceYourText iOS app. It provides serverless API endpoints for text-to-speech generation using Google's Gemini 2.0 Flash API with TTS capabilities.

## Build and Development Commands

### Setup
```bash
# Navigate to server directory
cd server

# Install dependencies
npm install

# Copy and configure environment variables
cp .env.example .env
# Edit .env with your Gemini API key and Firebase project details

# Configure Firebase project
firebase use --add
firebase functions:config:set gemini.api_key="your-api-key"
```

### Development
```bash
# Build TypeScript
npm run build

# Watch for changes
npm run build:watch

# Run local emulator
npm run serve

# Run tests
npm test
```

### Deployment
```bash
# Deploy to Firebase
npm run deploy

# View logs
npm run logs
```

## Architecture Overview

### Tech Stack
- **Firebase Functions v2**: Serverless compute platform
- **TypeScript**: Type-safe development
- **Gemini AI API**: Google's multimodal AI model with TTS support
- **Firebase Storage**: Audio file storage
- **Firebase Admin SDK**: Backend service integration

### Project Structure
```
server/
├── src/
│   ├── index.ts         # Main function definitions
│   ├── voiceConfig.ts   # Voice configuration and options
│   └── test/            # Unit tests
├── lib/                 # Compiled JavaScript (gitignored)
├── package.json         # Dependencies and scripts
├── tsconfig.json        # TypeScript configuration
└── firebase.json        # Firebase configuration
```

### Key Functions

#### `getVoices`
- **Method**: GET
- **Purpose**: Returns available TTS voices
- **Query Params**: `language` (optional) to filter by language

#### `generateAudio`
- **Method**: POST
- **Purpose**: Basic text processing with Gemini (no audio generation)
- **Body**: `{ text: string, language?: string }`

#### `generateAudioWithTTS`
- **Method**: POST  
- **Purpose**: Full TTS audio generation with Gemini 2.0 Flash
- **Body**: `{ text: string, voiceId?: string, style?: string, language?: string }`
- **Returns**: Public URL to generated WAV file in Firebase Storage

### Voice Configuration
Available voices are defined in `voiceConfig.ts`:
- **Zephyr**: Cheerful female voice
- **Puck**: Playful male voice
- **Kore**: Professional female voice
- **Charon**: Deep male voice
- **Fenrir**: Strong male voice

### Audio Storage Pattern
1. Gemini generates base64 audio data
2. Convert to Buffer
3. Save to Firebase Storage with unique filename: `audio/{voiceId}_{timestamp}_{uuid}.wav`
4. Make file publicly accessible
5. Return public URL to client

## Development Guidelines

### Error Handling
- Always validate request method and required parameters
- Return structured error responses with appropriate HTTP status codes
- Log errors using Firebase logger for debugging
- Include helpful error messages for invalid voice IDs

### Type Safety
- Use TypeScript types for all request/response objects
- Import Firebase Functions types: `Request, Response`
- Define interfaces for voice configurations
- Avoid `any` types where possible

### Testing Strategy
- Unit tests using Mocha framework
- Mock external dependencies (Gemini API, Firebase Storage)
- Test error conditions and edge cases
- Validate request/response contracts

### Security Considerations
- CORS is enabled for all endpoints (`cors: true`)
- Consider adding authentication for production use
- Validate and sanitize user input
- Set appropriate file permissions in Storage

### Performance Optimization
- Audio files are cached in Firebase Storage
- Use unique filenames to avoid collisions
- Consider implementing rate limiting for production
- Monitor function cold starts and optimize if needed

## Common Tasks

### Adding a New Voice
1. Add voice configuration to `availableVoices` array in `voiceConfig.ts`
2. Ensure the `wavenetVoice` matches a valid Gemini TTS voice name
3. Update tests if needed

### Modifying Audio Output Format
1. Update the `generationConfig` in `generateAudioWithTTS`
2. Adjust file extension and MIME type accordingly
3. Update Storage metadata content type

### Debugging Failed Generations
1. Check Firebase Functions logs: `npm run logs`
2. Verify Gemini API key is set correctly
3. Ensure Firebase Storage bucket exists and has proper permissions
4. Check that the voice ID is valid

## Environment Variables

Required environment variables in `.env`:
- `GEMINI_API_KEY`: Your Google Gemini API key
- `FIREBASE_PROJECT_ID`: Your Firebase project ID
- `GOOGLE_CLOUD_PROJECT_ID`: Your GCP project ID

Set in Firebase config:
```bash
firebase functions:config:set gemini.api_key="your-key"
```

## Deployment Checklist

Before deploying to production:
- [ ] Test all endpoints locally with emulator
- [ ] Verify environment variables are set
- [ ] Run unit tests: `npm test`
- [ ] Check TypeScript compilation: `npm run build`
- [ ] Review Firebase Storage permissions
- [ ] Consider implementing authentication
- [ ] Set up monitoring and alerts
- [ ] Document API changes in README.md