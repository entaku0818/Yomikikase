# Project guide

AGENTS.mdとCLAUDE.mdから参照する共通ガイドです。アーキテクチャ・コマンド・開発ルールはこのファイルを更新し、入口ファイルに複製しないでください。コマンドは特記がなければリポジトリルートを基準とします。

## Project Overview

Voice Narrator (VoiceYourText) is an iOS app that provides text-to-speech functionality for Japanese and multiple other languages. It's built with SwiftUI and The Composable Architecture (TCA), featuring text input, PDF reading, user dictionaries, and subscription management.

## Build and Development Commands

### Basic Development
```bash
# Navigate to iOS directory
cd iOS

# Open project in Xcode
open VoiceYourText.xcodeproj

# Resolve the Xcode project dependencies
xcodebuild -resolvePackageDependencies -project VoiceYourText.xcodeproj -scheme VoiceYourText

# Run the app unit tests (from iOS/)
./scripts/ci_ios.sh config
./scripts/ci_ios.sh test
```

### Testing
- Unit tests are located in `iOS/VoiceYourTextTests/`
- Run specific test files:
  - `PDFReaderFeatureTests.swift` - PDF reading functionality tests
  - `SettingsReducerTests.swift` - Settings and language configuration tests
  - `YomikikaseTests.swift` - Core app functionality tests

### CI (GitHub Actions)
- iOS / Android / Functions の実行条件・ローカル再現コマンド・xcconfig設定は [開発ガイド](development.md) を参照。Functionsの環境変数とデプロイ手順は [functions/README.md](../functions/README.md) を参照。
- `.github/workflows/ios-ci.yml` — iOS の build / unit test。entaku の Mac に登録した **self-hosted runner**（labels: `self-hosted, macOS, xcode27`）で実行する
  - **GitHub-hosted の `macos-*` ランナーは課金されるため禁止**。iOS のジョブは self-hosted（ios-ci.yml）のみ可
  - フォークからの PR では実行しない（job の `if:` で制限）
  - コマンドは `iOS/scripts/ci_ios.sh {config|build|test}` に集約。ローカルでも同じコマンドで再現できる
  - Debug 構成のみ。`Debug.xcconfig` が無ければダミー値で生成する（Release 用の秘密情報は CI で扱わない）
- `.github/workflows/ci.yml` — SwiftLint（ubuntu コンテナ、リポジトリルートから実行）
- Xcode Cloud は使っていない（2026-09 に撤去）

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

# 4. Keep build artifacts for verification and reuse.
# Do not delete build/: it also contains DerivedData and its build cache.
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
- `iOS/VoiceYourText/Features/PDFReader/` - PDF viewing and text extraction
- `iOS/VoiceYourText/Features/Settings/` - App settings and subscription management
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
- `KokoroTTSClient` — local MLX synthesis; see [KokoroSwift setup](../iOS/LocalPackages/KokoroSwift/README.md)
- `UserDefaultsClient` — injectable settings storage; tests can use an isolated UserDefaults suite
- Speech synthesis and PDF handling, including tapping PDF text to begin reading
- User dictionary management

### Data Layer
- **Core Data**: `SpeechText.xcdatamodeld` for persistent speech content
- **Repository Pattern**: `SpeechTextRepository` for data access
- **UserDefaults**: Managed via `UserDefaultsManager` for app settings
- **Multi-language Support**: 13 speech-language choices in `Setting.State.availableLanguages`; the app string catalog currently contains 10 translation locales (de/en/es/fr/it/ja/ko/th/tr/vi). Speech language support does not imply UI translation coverage.

### External Integrations
- **Firebase**: Analytics and backend services
- **RevenueCat**: Subscription management
- **AdMob**: Advertisement integration (with premium subscription bypass)
- **AVFoundation**: Text-to-speech synthesis
- **PDFKit**: PDF document handling and tap-to-read interaction
- **KokoroSwift / MLX**: on-device Japanese/English TTS (iOS 18+), downloaded model and voice embeddings
- **PaywallAnalytics**: MLX-independent event contracts and automatic paywall policy; see [package guide](../iOS/LocalPackages/PaywallAnalytics/README.md)
- Legacy Cloud Run configuration: [environment variable guide](cloudrun-configuration.md)

## Key Development Patterns

### Template Usage
Use `iOS/VoiceYourText/Templates/ModernReducerTemplate.swift` as a starting point for new features. It demonstrates proper TCA structure with ViewAction pattern and dependency injection.

### Configuration Management
- Environment-specific configs in `iOS/VoiceYourText/config/` (.xcconfig files)
- API keys loaded from Info.plist or environment variables
- Debug vs Release builds handled via compiler directives

### Localization
- Primary localizations in `iOS/VoiceYourText/Localization/Localizable.xcstrings`
- Per-language InfoPlist.strings in language-specific .lproj folders
- Fastlane metadata has 13 locale directories for App Store submissions: de-DE, en-US, es-ES, fr-FR, it, ja, ko, pt-BR, ru, th, tr, vi, zh-Hans (`review_information` is not a locale).

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
