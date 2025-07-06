# Changelog

All notable changes to Voice Narrator (VoiceYourText) will be documented in this file.

## [0.11.0] - 2025-07-06

### ✨ New Features
- **Text Highlighting During Speech Synthesis**: Added real-time text highlighting that synchronizes with speech playback
  - Highlights currently spoken words in yellow during text-to-speech
  - Works across all text input areas (main text editor, full-screen text input)
  - Automatic scrolling to highlighted text position

- **PDF Text Highlighting**: Enhanced PDF reading experience with synchronized highlighting
  - PDF documents now highlight currently spoken text during audio playback
  - Automatic scrolling to highlighted sections within PDF
  - Seamless integration with existing PDF reading functionality

### 🔧 Technical Improvements
- Implemented `HighlightableTextView` using UITextView for precise text highlighting
- Enhanced `SpeechSynthesizerClient` with `speakWithHighlight` method
- Added `willSpeakRangeOfSpeechString` delegate support for real-time word tracking
- Improved PDF text search and selection functionality using PDFKit

### 🏗️ Architecture Updates
- Updated TCA (The Composable Architecture) state management for highlighting features
- Added new actions: `highlightRange`, `speechFinished`, `startSpeaking`, `stopSpeaking`
- Enhanced ViewStore bindings for real-time UI updates
- Maintained backward compatibility with existing speech synthesis features

### 📱 User Experience
- Visual feedback during speech synthesis makes it easier to follow along with audio
- Improved accessibility for users who benefit from visual text tracking
- Enhanced PDF reading experience with visual synchronization
- Smooth animations and transitions for highlighting effects

---

## [0.10.1] - Previous Release
- Bug fixes and stability improvements
- Performance optimizations

## [0.10.0] - Previous Release  
- PDF workflow redesign
- File management features
- UI/UX improvements