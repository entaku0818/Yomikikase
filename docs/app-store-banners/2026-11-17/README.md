# ヘッダーバナーの文字を読みやすくする案

ユーザー指摘「小さくて文字見えん」に対応した日本語・英語の比較案。**ローカルの案であり、App Store Connectへ未登録・未提出・未反映**。

追記: 「シンプルでいい」というフィードバックを受け、スマホ画像と波模様も外した文字中心の案を追加した。背景グラデーションと見出し2行だけに絞り、文字を270px（390px幅で27.42px相当）へ拡大。安全領域内に収まることを検証済み。

- [日本語・文字だけの案（390px幅）](ja-simple-390.png)／[原稿](simple/ja.png)
- [英語・文字だけの案（390px幅）](en-US-simple-390.png)／[原稿](simple/en-US.png)

## 比較と変更

1. 現行原稿は中央に小さく構図を収めており、390px幅では日本語の見出し・副文が読みにくい。特に日本語は既存の検索画像全体を縮小していた。
2. 修正版は副文を外し、「文章を、耳で読む。」の2行を主役にした。見出しは原稿上220px、幅390pxで22.34px相当。英語は同じ大きさで「Text to speech.」。
3. 背景の色・波形と実際の読み上げ画面を維持。見出し・端末枠・実ハイライト行の拡大は、中央の安全領域に収めた。

| 比較 | 390px幅 | 原稿 |
|---|---|---|
| 日本語 | [上下比較](ja-comparison-390.png) | [修正版3840×1646](after/ja.png) |
| 英語 | [上下比較](en-US-comparison-390.png) | [修正版3840×1646](after/en-US.png) |

`before/` は今回比較した現行原稿の写し。`source/` は6枚構成のスクショ撮影時の実UI・実ハイライト行の写し。比較は同じ390px幅で原稿全体を縮小したもので、実ストア表示やASC端末プレビューを取得した画像ではない。文字の内容と余白を目視し、RGB・寸法・安全領域・元ファイル保持も検証した。

[Appleの仕様](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications)を2026-11-17に再確認。ヘッダー3840×1646、安全領域1646×661（x1097/y493）。[制作指針](https://developer.apple.com/app-store/asset-best-practices/)の、短い文言と可読性を優先する方針に沿った変更。

## 再生成

```sh
swiftc iOS/scripts/compose_readable_store_header.swift -o /tmp/narrator-readable-header
/tmp/narrator-readable-header docs/app-store-banners/2026-11-17
# 文字だけのシンプルな案
/tmp/narrator-readable-header docs/app-store-banners/2026-11-17 --text-only
```

見た目と文字の大きさを確認してから、他言語の文言・表示幅へ展開する。今回の変更はバナー案のみで、提出済み1.4.15（53）の600枚のスクショや審査状態には書き込んでいない。
