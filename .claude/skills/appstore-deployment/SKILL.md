---
name: appstore-deployment
description: VoiceYourTextアプリのApp Store Connectへのデプロイメントをサポートします。Fastlaneを使用したメタデータアップロード、xcodebuildによるアーカイブとアップロード、多言語対応のローカリゼーション管理を含みます。
---

# App Store Deployment Skill

VoiceYourTextアプリのApp Store Connect へのデプロイメントと公開管理を行うスキルです。

## 概要

このスキルは以下の操作をサポートします:
- Fastlaneを使用したメタデータアップロード
- xcodebuildによるアプリのアーカイブとアップロード
- 多言語(10言語)のローカリゼーション管理
- スクリーンショットの更新
- バージョン管理とリリースノート

## Instructions

### 1. Fastlaneでメタデータのみをアップロードする

**目的**: バイナリなしでアプリの説明文やスクリーンショットを更新

**手順**:
```bash
cd iOS
bundle install
bundle exec fastlane ios upload_metadata_only
```

**対象ファイル**:
- `iOS/fastlane/metadata/{locale}/` - 各言語のメタデータ
  - `name.txt` - アプリ名
  - `description.txt` - アプリ説明
  - `keywords.txt` - キーワード
  - `promotional_text.txt` - プロモーションテキスト
  - `release_notes.txt` - リリースノート

**対応言語**:
- 日本語 (ja)
- 英語 (en-US)
- ドイツ語 (de-DE)
- スペイン語 (es-ES)
- フランス語 (fr-FR)
- イタリア語 (it)
- 韓国語 (ko)
- トルコ語 (tr)
- ベトナム語 (vi)
- タイ語 (th)

### 2. xcodebuildでアーカイブとアップロードを実行する

**目的**: アプリバイナリをApp Store Connectにアップロード

**手順**:
```bash
cd iOS

# 0. Xcodeバージョンの確認（重要！）
xcodebuild -version
xcrun swift --version  # Swiftバージョン確認

# 依存関係とSwiftバージョンが一致しない場合はXcodeを切り替え
# sudo xcode-select -s /Applications/Xcode-26.1.0.app/Contents/Developer

# 1. DerivedDataのクリーンアップ（推奨）
rm -rf ~/Library/Developer/Xcode/DerivedData/VoiceYourText-*

# 2. アーカイブの作成
xcodebuild -scheme VoiceYourText \
  -project VoiceYourText.xcodeproj \
  -archivePath build/VoiceYourText.xcarchive \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  archive

# 3. ExportOptions.plistの作成
cat > build/ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>4YZQY4C47E</string>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
</dict>
</plist>
EOF

# 4. IPAのエクスポート
xcodebuild -exportArchive \
  -archivePath build/VoiceYourText.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates

# 5. App Store Connectにアップロード
# API keyファイルが~/.appstoreconnect/private_keys/にあること確認
xcrun altool --upload-app \
  --type ios \
  --file build/export/VoiceYourText.ipa \
  --apiKey R2Q4FFAG8D \
  --apiIssuer 3cc1c923-009c-4963-a9db-83d030e4c4e3

# 6. ビルドフォルダのクリーンアップ
rm -rf build
```

**重要**: `-destination 'generic/platform=iOS'` を指定することで、特定デバイスではなくiOS全般向けにビルドされます。

### 3. Fastlaneでメタデータとバイナリをアップロードする

**目的**: メタデータの更新とバイナリのアップロードを同時に実行

**手順**:
```bash
cd iOS
bundle exec fastlane ios upload_metadata
```

**注意**: このコマンドはバイナリが必要なため、事前にアーカイブを作成しておく必要があります。

### 4. ローカリゼーションファイルを更新する

**目的**: アプリの説明文やリリースノートを多言語で更新

**手順**:
1. 対象言語のディレクトリを開く: `iOS/fastlane/metadata/{locale}/`
2. 必要なファイルを編集:
   - `description.txt` - アプリの説明(最大4000文字)
   - `release_notes.txt` - 更新内容(最大4000文字)
   - `keywords.txt` - キーワード(カンマ区切り、最大100文字)
3. 変更をコミット
4. Fastlaneでアップロード

**例**:
```bash
# 日本語の説明文を編集
vim iOS/fastlane/metadata/ja/description.txt

# 英語のリリースノートを編集
vim iOS/fastlane/metadata/en-US/release_notes.txt

# アップロード
cd iOS
bundle exec fastlane ios upload_metadata_only
```

### 5. スクリーンショットを更新する

**目的**: App Storeのスクリーンショットを更新

**手順**:
1. 各デバイスサイズのスクリーンショットを準備
2. ファイル名規則に従って保存: `iOS/fastlane/screenshots/{locale}/{device}-{number}.png`
3. Fastlaneでアップロード

**デバイスサイズ**:
- iPhone 6.7" (iPhone 14 Pro Max, 15 Pro Max)
- iPhone 6.5" (iPhone 11 Pro Max, XS Max)
- iPhone 5.5" (iPhone 8 Plus, 7 Plus)
- iPad Pro 12.9" (第3世代以降)

### 6. バージョン番号を更新する

**目的**: 新バージョンをリリースするためにバージョン番号を更新

**手順**:
```bash
cd iOS

# 1. 現在のバージョンを確認
xcodebuild -project VoiceYourText.xcodeproj -scheme VoiceYourText -showBuildSettings | grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION"

# 2. バージョンを更新（agvtoolを使用）
xcrun agvtool new-marketing-version 0.16.0  # マーケティングバージョン
xcrun agvtool next-version -all              # ビルド番号をインクリメント

# 3. project.pbxprojも直接更新（agvtoolで更新されない場合）
sed -i '' 's/MARKETING_VERSION = 0.15.1;/MARKETING_VERSION = 0.16.0;/g' VoiceYourText.xcodeproj/project.pbxproj

# 4. 変更を確認
git diff VoiceYourText.xcodeproj/project.pbxproj

# 5. リリースノートを全言語で更新
# fastlane/metadata/{locale}/release_notes.txt を編集

# 6. 変更をコミット
git add VoiceYourText.xcodeproj/project.pbxproj fastlane/metadata/*/release_notes.txt
git commit -m "release: Update version to 0.16.0"

# 7. Gitタグを作成
git tag v0.16.0
git push && git push --tags
```

### 7. App Store Connect API keyの設定

**目的**: xcrun altoolでアップロードするためのAPI key設定

**手順**:
```bash
# 1. API keyディレクトリを作成
mkdir -p ~/.appstoreconnect/private_keys

# 2. fastlane/.envからAPI keyを取得してファイルを作成
# KEY_ID: R2Q4FFAG8D
# ISSUER_ID: 3cc1c923-009c-4963-a9db-83d030e4c4e3

cat > ~/.appstoreconnect/private_keys/AuthKey_R2Q4FFAG8D.p8 << 'EOF'
-----BEGIN PRIVATE KEY-----
[fastlane/.envのAPI_KEY_CONTENTをコピー]
-----END PRIVATE KEY-----
EOF

# 3. パーミッション設定
chmod 600 ~/.appstoreconnect/private_keys/AuthKey_R2Q4FFAG8D.p8
```

**API key情報の取得**:
- `iOS/fastlane/.env` ファイルに保存されています
- `APP_STORE_CONNECT_API_KEY_KEY_ID`
- `APP_STORE_CONNECT_API_KEY_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_CONTENT`

## Usage Examples

### 例1: リリースノートの更新

**ユーザーの要求**:
> 「次のバージョンのリリースノートを10言語すべてで更新してほしい」

**実行内容**:
1. 各言語の`release_notes.txt`を編集
2. 新機能と修正内容を記載
3. Fastlaneでメタデータをアップロード

**結果**: App Store Connectで次のバージョンのリリースノートが更新される

### 例2: 新バージョンのアップロード

**ユーザーの要求**:
> 「バージョン1.2.0をApp Store Connectにアップロードしたい」

**実行内容**:
1. Info.plistでバージョン番号を1.2.0に更新
2. xcodebuildでアーカイブ作成
3. ExportOptions.plistを作成
4. エクスポートとアップロード実行
5. ビルドフォルダをクリーンアップ

**結果**: App Store Connectに新しいビルドがアップロードされる

### 例3: 多言語説明文の一括更新

**ユーザーの要求**:
> 「アプリの説明文を全言語で更新したい」

**実行内容**:
1. `iOS/fastlane/metadata/`の各言語フォルダを確認
2. 各`description.txt`を編集
3. `bundle exec fastlane ios upload_metadata_only`を実行

**結果**: 全言語のApp Store説明文が更新される

## Key Files and Directories

### Fastlane関連
- `iOS/Fastfile` - Fastlaneの設定ファイル
- `iOS/Appfile` - アプリIDとTeam IDの設定
- `iOS/fastlane/metadata/{locale}/` - 各言語のメタデータ

### ローカリゼーション
- `iOS/VoiceYourText/locate/Localizable.xcstrings` - アプリ内テキスト
- `iOS/VoiceYourText/{locale}.lproj/InfoPlist.strings` - App名とパーミッション説明

### ビルド設定
- `iOS/VoiceYourText.xcodeproj/project.pbxproj` - Xcodeプロジェクト設定
- `iOS/VoiceYourText/Info.plist` - アプリメタデータとバージョン
- `iOS/VoiceYourText/config/*.xcconfig` - 環境別設定ファイル

## Troubleshooting

### 問題1: Fastlaneの認証エラー

**原因**: App Store Connect APIキーまたはApple IDの認証が失敗

**解決策**:
1. `fastlane/Appfile`でApple IDを確認
2. App Store Connect APIキーが正しいか確認
3. 2段階認証が有効な場合、App固有パスワードを使用
4. `fastlane spaceauth`で認証情報を更新

### 問題2: xcodebuildのアーカイブ失敗

**原因**: コード署名またはプロビジョニングプロファイルの問題

**解決策**:
1. Xcodeで自動署名が有効か確認
2. チームIDが正しいか確認: `4YZQY4C47E`
3. `-allowProvisioningUpdates`フラグを使用
4. Keychainで証明書の有効期限を確認

### 問題3: メタデータアップロードが部分的に失敗

**原因**: 特定言語のメタデータファイルが不正

**解決策**:
1. エラーログで対象言語とファイルを確認
2. ファイルのエンコーディングがUTF-8か確認
3. 文字数制限を超えていないか確認
4. 必須ファイルが揃っているか確認

### 問題4: スクリーンショットのサイズエラー

**原因**: スクリーンショットのサイズが要件を満たしていない

**解決策**:
1. 各デバイスの正確なピクセルサイズを確認:
   - iPhone 6.7": 1290x2796
   - iPhone 6.5": 1242x2688
   - iPad Pro 12.9": 2048x2732
2. PNG形式で保存
3. sRGBカラースペースを使用

## Best Practices

1. **バージョン管理**: 各リリースにGit tagを付ける
2. **段階的リリース**: TestFlightで先行テストしてから公開
3. **リリースノート**: 各言語で具体的な変更内容を記載
4. **スクリーンショット**: 最新機能を反映した画像を使用
5. **メタデータ**: SEO を意識したキーワード選定
6. **ローカリゼーション**: ネイティブスピーカーによるレビュー
7. **自動化**: CI/CDでビルドとアップロードを自動化

## Notes

- App Store Connectへのアップロードには約10-20分かかります
- メタデータの更新は即座に反映されます(審査不要)
- バイナリの審査には通常1-2日かかります
- TeamID `4YZQY4C47E` は環境に応じて変更してください
- Fastlaneは`Gemfile`で管理されているため、`bundle exec`経由で実行
- 本番環境では`Release`ビルド構成を使用
- デバッグシンボルは自動的にアップロードされます
