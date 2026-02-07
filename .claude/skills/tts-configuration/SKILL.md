---
name: tts-configuration
description: VoiceYourTextアプリのTTS(Text-to-Speech)設定を管理します。クラウドTTSと基本TTS(デバイスTTS)の切り替え、音声パラメータ(速度・高さ)の調整、音声エンジンの選択をサポートします。
---

# TTS Configuration Skill

VoiceYourTextアプリのText-to-Speech機能の設定と管理を行うスキルです。

## 概要

このスキルは以下の操作をサポートします:
- クラウドTTSと基本TTS(デバイスTTS)の切り替え設定
- 音声速度(speechRate)と音声高さ(speechPitch)の調整
- TTS音声エンジンの選択と設定
- TTSキャッシュの管理

## Instructions

### 1. TTS方式の切り替え設定を追加/変更する

**目的**: ユーザーが再生時にクラウドTTSと基本TTSを切り替えられるようにする

**手順**:
1. `TextInputView.swift`を確認
2. `useCloudTTS`と`cloudTTSAvailable`の状態変数を確認
3. `checkCloudTTSAvailability()`関数でクラウドTTS音声の有無をチェック
4. プレイヤーUIにセグメントコントロールを追加
5. 再生ロジック(`speakWithHighlight`)でユーザーの選択を反映

**期待される結果**:
```swift
// TextInputView.swift
@State private var useCloudTTS: Bool = true
@State private var cloudTTSAvailable: Bool = false

private func checkCloudTTSAvailability() {
    // クラウドTTS音声ファイルの存在確認
}
```

### 2. 音声パラメータの数値表示を追加する

**目的**: 設定画面で音声速度と高さを数値で表示する

**手順**:
1. `LanguageSettingView.swift`を開く
2. 音声設定セクション(Section header: "音声設定")を探す
3. スライダーの上部にHStackを追加し、現在値を数値で表示
4. `String(format: "%.1f", value)`で小数点1桁まで表示

**期待される結果**:
```swift
HStack {
    Text("声の速さ")
        .font(.headline)
    Spacer()
    Text(String(format: "%.1f", store.speechRate))
        .font(.system(.body, design: .monospaced))
        .foregroundColor(.blue)
}
```

### 3. UserDefaultsManagerの設定値を確認/変更する

**目的**: TTS設定の永続化と取得

**確認すべき設定**:
- `languageSetting`: 言語設定
- `selectedVoiceIdentifier`: デバイスTTS音声ID
- `cloudTTSVoiceId`: クラウドTTS音声ID
- `speechRate`: 音声速度 (0.0-2.0)
- `speechPitch`: 音声高さ (0.5-2.0)

**ファイル**: `iOS/VoiceYourText/data/UserDefaultsManager.swift`

### 4. TTSキャッシュを管理する

**目的**: クラウドTTS音声ファイルのキャッシュをクリアする

**手順**:
1. `LanguageSettingView.swift`の`CacheManagementView`を確認
2. `audioFileManager.clearCache()`でキャッシュをクリア
3. 音声ファイルは`Documents/audio/`ディレクトリに保存される

## Usage Examples

### 例1: TTS切り替えトグルの追加

**ユーザーの要求**:
> 「基本TTSの設定を有効にしてほしい」

**実行内容**:
1. TextInputView.swiftに`useCloudTTS`状態変数を追加
2. クラウドTTS音声の有無をチェックする関数を実装
3. プレイヤー画面にセグメントコントロールを追加
4. 再生ロジックを更新

**結果**: ユーザーが再生時にクラウドTTSと基本TTSを切り替えられるようになる

### 例2: 音声設定の数値表示

**ユーザーの要求**:
> 「音声設定を数値で見せてほしい」

**実行内容**:
1. LanguageSettingView.swiftの音声設定セクションを更新
2. 声の速さと声の高さのスライダーに数値表示を追加

**結果**: 設定画面で現在の音声パラメータが数値(例: 0.5, 1.2)で表示される

### 例3: デフォルトTTS方式の設定

**ユーザーの要求**:
> 「デフォルトでクラウドTTSを使用するようにしたい」

**実行内容**:
1. `useCloudTTS`の初期値を`true`に設定
2. 音声生成完了時に`useCloudTTS = true`を設定

**結果**: クラウドTTS音声が利用可能な場合、デフォルトで選択される

## Key Files

- `iOS/VoiceYourText/TextInputView.swift` - テキスト入力とTTS再生UI
- `iOS/VoiceYourText/setting/LanguageSettingView.swift` - 音声設定画面
- `iOS/VoiceYourText/data/UserDefaultsManager.swift` - TTS設定の永続化
- `iOS/VoiceYourText/Features/Player/SpeechSettings.swift` - 音声設定の定数
- `iOS/VoiceYourText/Features/NowPlaying/NowPlayingFeature.swift` - 再生状態管理

## Troubleshooting

### 問題1: TTS切り替えトグルが表示されない

**原因**: クラウドTTS音声ファイルが存在しない

**解決策**:
1. `checkCloudTTSAvailability()`が正しく呼ばれているか確認
2. `Documents/audio/{fileId}.wav`ファイルが存在するか確認
3. テキスト保存時にクラウドTTS生成が成功しているか確認

### 問題2: 基本TTSで音声速度が反映されない

**原因**: AVSpeechUtteranceのrateプロパティが正しく設定されていない

**解決策**:
1. `UserDefaultsManager.shared.speechRate`が正しく取得されているか確認
2. `playWithDeviceTTS()`でrateが適用されているか確認
3. デフォルト値が0の場合は0.5を使用するロジックを確認

### 問題3: クラウドTTS音声が再生されない

**原因**: 音声ファイルのパスが間違っているか、ファイルが破損している

**解決策**:
1. ログで`[Highlight]`タグを確認し、再生パスを確認
2. `audioFileManager`でファイルが正しくダウンロードされているか確認
3. 必要に応じてキャッシュをクリアして再生成

## Notes

- クラウドTTS音声は`.wav`形式で保存される
- タイムポイント情報は`.json`形式で保存される
- 基本TTSはハイライト機能をサポート
- クラウドTTSはタイムポイントベースのハイライトを使用
- 音声速度の範囲: 0.0-2.0 (0.5がデフォルト/通常速度)
- 音声高さの範囲: 0.5-2.0 (1.0がデフォルト)
