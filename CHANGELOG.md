# Changelog

All notable changes to Voice Narrator (VoiceYourText) will be documented in this file.

## [0.12.0] - 2025-01-03

### ✨ New Features

- **Mini Player**: Added YouTube/Apple Music-style mini player for audio playback
  - Appears at the bottom of the screen when audio is playing
  - Shows title, playback status, and progress bar
  - Tap to return to the original playback screen
  - Stop button to stop audio (keeps mini player visible)
  - Dismiss button (×) to completely close mini player
  - Speaker icon animates during playback

- **Background Audio Continuation**: Audio continues playing when closing file views
  - Close TextInputView or PDFReaderView while audio plays
  - Mini player appears in main view for continued control
  - Tap mini player to reopen the original file

- **Unified Player Controls**: Consistent playback UI across all views
  - Play/Stop button centered
  - Speed selector on the right
  - Shared speed options without Japanese text labels

- **Full Screen File Views**: Files open in fullScreenCover (hides tab bar)
  - Close button (×) in top left
  - TextInputView: Edit mode → Player mode flow
  - PDFReaderView: Integrated player controls

### 🏗️ Architecture Updates

- Added `NowPlayingFeature` reducer for global playback state management
- Added `PlaybackSource` enum with navigation info (fileId, text, url)
- Created `SpeechSettings` for shared speed options
- Created `PlayerControlView` as reusable player control component
- Updated parent store integration for PDFReaderView

### 📁 New Files

- `Features/NowPlaying/NowPlayingFeature.swift` - Playback state reducer
- `Features/NowPlaying/MiniPlayerView.swift` - Mini player UI
- `Features/Player/PlayerControlView.swift` - Shared player controls
- `Features/Player/SpeechSettings.swift` - Shared speed settings

---

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