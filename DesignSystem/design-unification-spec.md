# ナレーター — デザイン統一 仕様書

> アプリ全体の「色・操作・余白」を 1 つのルールに揃え、画面ごとの矛盾をなくすための変更仕様。
> 確定ブランドカラーは **インディゴ**。本書はキャンバスのビジュアル案に対応する実装ハンドオフ。
>
> v1.0 · 2026-06-07 · 対象: iOS（SwiftUI / TCA） · 元 HTML: [`assets/source-html/デザイン統一 仕様書.html`](./assets/source-html/)

## 目次

1. [背景と原則](#01--背景と原則)
2. [カラートークン](#02--カラートークン)
3. [アイコン統一ルール](#03--アイコン統一ルール)
4. [統一プレイヤー仕様](#04--統一プレイヤー仕様)
5. [画面別の変更点](#05--画面別の変更点)
6. [余白・角丸・影・文字](#06--余白角丸影文字)
7. [実装チェックリスト](#07--実装チェックリスト)

---

## 01 — 背景と原則

現状 `AppTheme.swift` には「アクセントは Indigo で統一」「グラデーション不使用」と明記されているのに、本体 UI では守られていない。3 つの矛盾:

1. ホームのアイコンが 7 色（青・赤・紫・緑・茶・グレー・水色）に分かれている
2. 再生ボタンの色が画面ごとに違う（テキスト=青 / PDF=オレンジ / ミニプレイヤー=黒）
3. プレイヤーの操作系がテキストと PDF で全く別物

### 統一の 3 原則

- **1 色ルール**: 意味を持つ UI（操作・誘導）はすべてアクセント 1 色。機能ごとの色分けは廃止
- **1 操作系ルール**: 再生・一時停止・スキップは、どのコンテンツでも同じ部品・同じ並び
- **ネイティブ準拠**: SF Symbols・大タイトル・グループ化リスト・システムカラーを尊重し、ライト/ダーク両対応

---

## 02 — カラートークン

アクセントはインディゴに確定。ダークモードは黒背景でのコントラスト確保のため明度を上げる。
`AppTheme` を「全画面が参照する唯一の色の出どころ」として拡張する。

| 用途 | ライト | ダーク |
|---|---|---|
| アクセント | `#4B47E0` | `#8B87FF` |
| アクセント soft（地） | accent 10〜20% | accent 10〜20% |
| 背景（グループ） | `#F2F2F7` | `#000000` |
| カード / セル | `#FFFFFF` | `#1C1C1E` |
| 本文テキスト | `#1C1C1E` | `#FFFFFF` |
| 補助テキスト | label・60% | label・60% |
| 区切り線 | separator | separator |

> **適用ルール**: アクセント = 再生ボタン・全アイコン・CTA・タブのアクティブ・進捗バー・選択中のフィルタ。
> それ以外（文字・背景・区切り線）はすべてニュートラル。**グラデーション禁止。**

### SwiftUI への落とし込み（AppTheme 拡張）

```swift
// AppTheme.swift — アクセントをカスタム Indigo に固定し、soft を追加
enum AppTheme {
    // Asset Catalog に Light/Dark 2値で登録した色を参照
    static let primary       = Color("AccentIndigo")   // L:#4B47E0 / D:#8B87FF
    static let primarySoft   = primary.opacity(0.12)   // アイコン地・選択地
    static let onPrimary     = Color.white
    // 背景・文字はシステムカラーをそのまま使う（ダーク自動対応）
    static let groupedBg     = Color(.systemGroupedBackground)
    static let card          = Color(.secondarySystemGroupedBackground)
}
```

バッジ・課金カードに使っていた `Color.orange` / `Color.indigo` 直書きは廃止し、すべて `AppTheme.primary` 経由に統一する。

---

## 03 — アイコン統一ルール

`HomeView.swift` の `createButtonContent` は現在、ソースごとに `iconColor` を個別指定している。
この引数を撤廃し、**すべて `AppTheme.primary`** に固定する。地（背景）は `primarySoft`。

| ソース | SF Symbol | 現状の色 → 変更後 |
|---|---|---|
| テキスト | `doc.text.fill` | 青 → アクセント |
| PDF | `doc.richtext.fill` | 赤 → アクセント |
| TXT ファイル | `doc.plaintext.fill` | 紫 → アクセント |
| G ドライブ | `externaldrive.fill` | 緑 → アクセント |
| 本（EPUB） | `books.vertical.fill` | 茶 → アクセント |
| スキャン | `camera.fill` | グレー → アクセント |
| リンク | `link` | 水色 → アクセント |

> **形状ルール**: アイコン地は 52×52 / 角丸 15（ホームタイル）、リスト行は 40×40 / 角丸 11。
> アイコン本体サイズ・ウェイトはタイルとリストで統一。
> `createButtonCard` は `createButtonContent` と重複しているので削除して 1 つに統合する。

---

## 04 — 統一プレイヤー仕様

今ある 3 種類の再生 UI を廃止し、**1 つの共通操作バー**に統合する。テキスト・PDF・スキャン・EPUB・Web、すべて同じ部品を使う。

| 画面 | 現状 | 統一後 |
|---|---|---|
| PDF（PlayerControlView 系） | オレンジ丸・15 秒送りのみ | 共通 PlayerBar |
| テキスト | 青丸・停止/速度/情報 | 共通 PlayerBar |
| ミニプレイヤー | 黒の再生アイコン | 共通 PlayerBar |

### 共通 PlayerBar の構成（固定）

下から順に積む。コントロール行の**並びはどの画面でも不変**。

- **スクラバー**: 左に経過、右に残り（PDF は「1 ページ / 12」表記）。塗りは `AppTheme.primary`、つまみは白丸。
- **コントロール行**（左→右で固定）: `速度ピル` ・ `15秒戻し` ・ `再生/一時停止（アクセント丸・66pt）` ・ `15秒送り` ・ `声/設定`
- **再生ボタン**: 直径 66pt・アクセント塗り・白アイコン・薄いアクセントの影。【全画面共通】
- **停止の扱い**: 「停止（stop）」と「一時停止（pause）」が混在しているので **pause/play トグルに統一**。停止は廃止。

> **削除するもの [DELETE]**: PDF のオレンジ `#FF9500` 再生ボタン／テキスト画面の青 `stop.fill`／`systemGray5` 地の info・speed 角丸ボタン／ミニプレイヤーの `foregroundColor(.primary)`（黒）再生アイコン。

> **ミニプレイヤーの変更 [MODIFY]**: 再生アイコンを `.primary` から `AppTheme.primary` に変更。スピーカー波形アイコンもアクセント色で揃える。

### 速度ピルの仕様

現状の `x1.0` 表記（systemGray5 の角丸）を、**fill の丸ピル + `1.0×` 表記**に統一。タップでシート表示は踏襲。

---

## 05 — 画面別の変更点

### ホーム `HomeView.swift`

- ナビタイトルを `Voice Narrator` から **「ナレーター」**に統一（タブ名・アプリ名と一致）。サブタイトルで用途を一言。
- ソースタイルのアイコンを全アクセント化（§03）。
- 「最近のファイル」行の再生ボタンを、青の `play.circle` から**アクセント塗りの丸 `play.fill`** に変更。

### マイファイル `MyFilesView.swift` 【空状態】

- ファイル一覧（アイコン地=アクセント・進捗バー・更新日）を整える。
- 上部に**検索フィールド**と**セグメントフィルタ**（すべて / PDF / テキスト / 本）。選択中のみアクセント。
- ファイルが 0 件のときの**エンプティステート**（アクセントのアイコン + 「ホームから読み込もう」導線）。

### 設定 `LanguageSettingView / SettingsView`

- 最上部に**プレミアム誘導バナー**（アクセント地・王冠）。課金導線をアクセントに集約。
- グループ化リストで「読み上げ（言語・声・速度）」「一般（辞書・削除項目・バックグラウンド再生）」を整理。行アイコン地は `primarySoft`。
- 速度はインラインのスライダー行（つまみ=白、塗り=アクセント、右端に `1.0×`）。

### プレミアム `SubscriptionView.swift`

- 年額カードは**アクセントの枠 +「2 ヶ月分お得」バッジ**、月額は控えめなニュートラル枠。`Color.orange` バッジは廃止しアクセントに。
- 特典リストのチェックは `primarySoft` 地 + アクセントの `checkmark`。CTA はアクセント塗り。

### オンボーディング `OnboardingView.swift`

- アプリアイコン的なアクセント角丸 + スピーカー波形。見出し「読みたいものを、声に任せよう。」
- 3 つの特典を縦並び（アイコン地=アクセント soft）。CTA とページドットもアクセント。

---

## 06 — 余白・角丸・影・文字

バラバラな数値を、少数のスケールに丸める。

| 項目 | ルール |
|---|---|
| 角丸 | カード/シート **16** ・ セル/タイル **14〜18** ・ アイコン地 **11〜15** ・ ピル **100** |
| 画面端の余白 | 左右 **20** を基本（リスト内テキストは 16） |
| 影 | カードは `0 1 3 / 5%` の極薄 1 段のみ。多重影・濃い影は使わない。ダークは影を消し **0.5px の区切り線**で代替。 |
| 文字 | 大タイトル 32/700 ・ 見出し 20/700 ・ 本文 16/400 ・ 補助 13〜14（secondary）。最小フォント 12。 |
| ヒット領域 | タップ可能要素は **最低 44×44pt** を確保。 |

---

## 07 — 実装チェックリスト

- [ ] Asset Catalog に `AccentIndigo`（Light `#4B47E0` / Dark `#8B87FF`）を登録
- [ ] `AppTheme` に `primary / primarySoft / onPrimary` を定義、`Color.indigo`・`Color.orange` 直書きを全廃
- [ ] `HomeView` の `iconColor` 引数を撤廃し全アイコンをアクセント化、`createButtonCard` 重複を統合
- [ ] 共通 `PlayerBar` を新設し、PDF/テキスト/ミニプレイヤーの再生 UI を置換
- [ ] 再生ボタンを pause/play トグルに統一（stop 廃止）、色をアクセントに
- [ ] ミニプレイヤーの再生アイコンを `.primary` → `AppTheme.primary`
- [ ] マイファイルの一覧・検索・フィルタ・空状態を実装
- [ ] 設定／課金／オンボーディングのアクセント・余白を本書に合わせて調整
- [ ] ライト/ダーク両方で全画面のコントラスト確認（最小フォント 12・ヒット領域 44）

> **対象ファイル**: `AppTheme.swift` / `HomeView.swift` / `MyFilesView.swift` / `Features/Player/PlayerControlView.swift` / `Features/NowPlaying/MiniPlayerView.swift` / `Features/PDFReader/PDFReaderFeature.swift` / `Features/Settings/SubscriptionView.swift` / `Features/Onboarding/OnboardingView.swift`
