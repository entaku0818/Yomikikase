# Voice Narrator v0.11.0 Release Notes

## 🎯 What's New in Version 0.11.0

### ✨ Text Highlighting Feature
音声合成中にテキストがハイライト表示される新機能を追加しました。

**主な機能:**
- **リアルタイムハイライト**: 音声合成中に現在読み上げている単語が黄色でハイライト表示
- **自動スクロール**: ハイライト位置に自動でスクロール
- **全画面対応**: メインテキストエディタ、フルスクリーンテキスト入力の両方で動作

### 📄 PDF読み上げ強化
PDFファイルの読み上げ時にも、現在読み上げている部分がハイライト表示されるようになりました。

**PDF機能:**
- **PDF内ハイライト**: PDF文書内で現在読み上げている部分をハイライト表示
- **自動ページ送り**: ハイライト部分が見えるように自動でスクロール
- **シームレス統合**: 既存のPDF読み上げ機能との完全統合

### 🔧 技術的改善
- **UITextView使用**: より正確なテキストハイライト表示
- **パフォーマンス向上**: スムーズなアニメーションと反応速度
- **アクセシビリティ**: 視覚的なテキスト追跡で読み上げを追いやすく

---

## 📲 App Store Description (Japanese)

**新機能: テキストハイライト対応**

音声合成中にテキストがリアルタイムでハイライト表示される新機能を追加しました。読み上げている部分が黄色でハイライトされ、自動でスクロールするため、音声と一緒にテキストを追うことができます。

PDFファイルの読み上げ時にも、PDF内で現在読み上げている部分がハイライト表示されるため、より読みやすく、理解しやすくなりました。

**主な改善点:**
• 音声合成中のリアルタイムテキストハイライト
• PDF読み上げ時のハイライト表示
• 自動スクロール機能
• 視覚的な読み上げ追跡
• アクセシビリティの向上

---

## 📲 App Store Description (English)

**New Feature: Text Highlighting**

Added real-time text highlighting during speech synthesis. The currently spoken text is highlighted in yellow and automatically scrolls, making it easy to follow along with the audio.

PDF reading has also been enhanced with highlighting within PDF documents, showing exactly which part is being read aloud for better comprehension.

**Key Improvements:**
• Real-time text highlighting during speech synthesis
• PDF highlighting during audio playback
• Automatic scrolling to highlighted text
• Visual speech tracking
• Enhanced accessibility features

---

## 🚀 Technical Details

**Architecture:**
- SwiftUI + The Composable Architecture (TCA)
- UITextView for precise text highlighting
- PDFKit integration for PDF highlighting
- AVSpeechSynthesizer with willSpeakRangeOfSpeechString delegate

**Compatibility:**
- iOS 16.4+
- iPhone and iPad
- All existing features maintained
- Backward compatible with previous versions