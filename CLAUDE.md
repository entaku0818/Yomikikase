# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Voice Narrator (VoiceYourText) is an iOS app that provides text-to-speech functionality for Japanese and multiple other languages. It's built with SwiftUI and The Composable Architecture (TCA), featuring text input, PDF reading, user dictionaries, and subscription management.

## Build and Development Commands

### Basic Development
```bash
# Navigate to iOS directory
cd iOS

# Open project in Xcode
open VoiceYourText.xcodeproj

# Resolve Swift Package dependencies
swift package resolve

# Run tests
swift test
```

### Testing
- Unit tests are located in `iOS/VoiceYourTextTests/`
- Run specific test files:
  - `PDFReaderFeatureTests.swift` - PDF reading functionality tests
  - `SettingsReducerTests.swift` - Settings and language configuration tests
  - `YomikikaseTests.swift` - Core app functionality tests

### Deployment (Fastlane)
```bash
# Navigate to iOS directory
cd iOS

# Install fastlane dependencies
bundle install

# Upload metadata only (without binary)
bundle exec fastlane ios upload_metadata_only

# Upload metadata and submit for review (requires binary)
bundle exec fastlane ios upload_metadata
```

### App Store Upload (Command Line)
```bash
cd iOS

# 1. Archive the app
xcodebuild -scheme VoiceYourText \
  -project VoiceYourText.xcodeproj \
  -archivePath build/VoiceYourText.xcarchive \
  -configuration Release \
  archive

# 2. Create ExportOptions.plist
cat > build/ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>4YZQY4C47E</string>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
EOF

# 3. Export and upload to App Store Connect
xcodebuild -exportArchive \
  -archivePath build/VoiceYourText.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates

# 4. Clean up build folder
rm -rf build
```

## Architecture Overview

### The Composable Architecture (TCA)
The app follows TCA patterns with:
- **State**: Immutable state structs with `@ObservableState`
- **Actions**: Enum with `ViewAction` and `BindableAction` patterns
- **Reducers**: Pure functions handling state updates and side effects
- **Dependencies**: Dependency injection via `@Dependency` property wrapper

### Key Architectural Components

#### Main Structure
- `VoiceYourTextApp.swift` - App entry point with Firebase and RevenueCat configuration
- `MainView.swift` - TabView container with 4 main tabs:
  - Speech input/playback (`SpeechView`)
  - PDF management (`PDFListView`) 
  - Speech content registration (`SettingsView`)
  - Language/voice settings (`LanguageSettingView`)

#### Feature Organization
Features are organized in domain-specific folders:
- `iOS/VoiceYourText/Features/UserDictionary/` - User dictionary management
- `iOS/VoiceYourText/PDFReader/` - PDF viewing and text extraction
- `iOS/VoiceYourText/setting/` - App settings and subscription management
- `iOS/VoiceYourText/data/` - Core Data repository and UserDefaults management

#### State Management Pattern
All reducers follow the modern TCA pattern:
```swift
@Reducer
struct FeatureReducer {
    @ObservableState
    struct State: Equatable { }
    
    enum Action: ViewAction, BindableAction {
        case binding(BindingAction<State>)
        case view(View)
        
        enum View { }
    }
}
```

#### Dependencies
Custom dependencies are implemented for:
- `AnalyticsClient` - Firebase Analytics integration
- Speech synthesis and PDF handling
- User dictionary management

### Data Layer
- **Core Data**: `SpeechText.xcdatamodeld` for persistent speech content
- **Repository Pattern**: `SpeechTextRepository` for data access
- **UserDefaults**: Managed via `UserDefaultsManager` for app settings
- **Multi-language Support**: 10 languages with localized greetings and content

### External Integrations
- **Firebase**: Analytics and backend services
- **RevenueCat**: Subscription management
- **AdMob**: Advertisement integration (with premium subscription bypass)
- **AVFoundation**: Text-to-speech synthesis
- **PDFKit**: PDF document handling

## Key Development Patterns

### Template Usage
Use `iOS/VoiceYourText/Templates/ModernReducerTemplate.swift` as a starting point for new features. It demonstrates proper TCA structure with ViewAction pattern and dependency injection.

### Configuration Management
- Environment-specific configs in `iOS/VoiceYourText/config/` (.xcconfig files)
- API keys loaded from Info.plist or environment variables
- Debug vs Release builds handled via compiler directives

### Localization
- Primary localizations in `iOS/VoiceYourText/locate/Localizable.xcstrings`
- Per-language InfoPlist.strings in language-specific .lproj folders
- Fastlane metadata supports 10 languages for App Store submissions

### Testing Strategy
- Unit tests for reducers and business logic
- UI tests for critical user flows
- Dependency injection enables easy mocking in tests

## Code Style Guidelines

- Follow standard Swift conventions and SwiftUI patterns
- Use TCA's ViewAction pattern for all new features
- Implement proper dependency injection for testability
- Maintain clear separation between UI, business logic, and data layers
- Use `@ObservableState` for all reducer states
- Prefer composition over inheritance in view hierarchies