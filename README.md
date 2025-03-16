# Voice Narrator (VoiceYourText)

![Version](https://img.shields.io/badge/version-0.7.1-blue)
![Platform](https://img.shields.io/badge/platform-iOS-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

テキストやPDFファイルを音声で読み上げるiOSアプリケーションです。

## 機能

### テキスト読み上げ
- テキスト入力と音声読み上げ
- 読み上げ速度と音程の調整
- 読み上げ内容の保存と管理

### PDFファイル読み上げ
- PDFファイルのインポートと管理
- PDFコンテンツの表示と読み上げ
- PDFファイルのテキスト抽出

### 設定
- 言語設定（複数言語対応）
- 音声パラメータのカスタマイズ
  - 読み上げ速度調整
  - 音声の高さ調整

## 技術スタック

- **SwiftUI**: モダンなUIフレームワーク
- **The Composable Architecture (TCA)**: 状態管理とビジネスロジック
- **AVFoundation**: 音声合成と再生
- **PDFKit**: PDFファイルの表示と操作
- **Firebase**: バックエンドサービス
- **XCTest**: ユニットテストとスナップショットテスト

## アーキテクチャ

このアプリケーションはThe Composable Architecture (TCA)を採用しています。TCAは以下の利点を提供します：

- 予測可能な単方向データフロー
- 明確な状態管理
- 副作用の分離
- テスト容易性
- 依存性注入

## 主要コンポーネント

### メイン画面
- **SpeechView**: テキスト入力と読み上げ機能
- **PDFListView**: PDFファイルの管理
- **SettingsView**: 読み上げ内容の登録
- **LanguageSettingView**: 言語と音声設定

### PDF機能
- **PDFListFeature**: PDFファイルのリスト表示と管理
- **PDFReaderFeature**: PDFファイルの表示と読み上げ
- **PDFKitView**: PDFファイルのレンダリング

### 設定
- **SettingsReducer**: 設定状態の管理
- **LanguageSettingView**: 言語設定UI
- **UserDefaultsManager**: 設定の永続化

## インストール

1. リポジトリをクローン
```
git clone https://github.com/entaku0818/Yomikikase.git
```

2. 依存関係をインストール
```
cd VoiceYourText
swift package resolve
```

3. Xcodeでプロジェクトを開く
```
open VoiceYourText.xcodeproj
```

## テスト

このプロジェクトには単体テストとスナップショットテストが含まれています：

```
cd VoiceYourText
swift test
```


## 連絡先

- 開発者: 遠藤拓弥
- GitHub: [entaku0818](https://github.com/entaku0818) 