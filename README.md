# Voice Narrator (VoiceYourText)

![Version](https://img.shields.io/badge/version-0.10.0-blue)
![Platform](https://img.shields.io/badge/platform-iOS-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

テキストやPDFファイルを音声で読み上げるiOSアプリケーションです。

## 🚀 最新アップデート (v0.10.0)

### 新機能
- **PDFワークフローの再設計**: シンプルで直感的なPDFファイル追加インターフェース
- **ファイル管理機能**: テキストファイルとPDFファイルのスワイプ削除機能
- **削除確認ダイアログ**: 誤操作防止のための安全な削除確認

### UI/UX改善
- **PDFファイルピッカー**: 複雑なPDFリストページをシンプルなファイル選択に変更
- **自動ナビゲーション**: PDF選択後、自動的にマイファイルページに遷移
- **安全な削除**: ファイル名表示付きの確認ダイアログ

### バグ修正
- **PDF読み上げ機能**: ユーザー設定を適用したPDF読み上げ機能の復旧
- **ファイル上書き**: 新規作成ではなく既存テキストファイルの上書き機能
- **バナー広告スペース**: 不要なスペースの削除
- **進捗表示**: 意味のない100%進捗表示の削除

## 機能

### テキスト読み上げ
- フルスクリーンテキスト入力と音声読み上げ
- 読み上げ速度と音程の調整
- 読み上げ内容の保存と管理
- 既存ファイルの編集と上書き保存

### PDFファイル読み上げ
- シンプルなPDFファイル追加機能
- PDFコンテンツの表示と読み上げ
- PDFファイルのテキスト抽出
- ファイル管理（スワイプ削除）

### ファイル管理
- 統合されたマイファイルビュー
- テキストファイルとPDFファイルの一覧表示
- スワイプ削除機能（確認ダイアログ付き）
- ダークモード対応

### 設定
- 多言語対応（10言語）
- 音声パラメータのカスタマイズ
  - 読み上げ速度調整
  - 音声の高さ調整
- プレミアム機能（無制限ファイル数）

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