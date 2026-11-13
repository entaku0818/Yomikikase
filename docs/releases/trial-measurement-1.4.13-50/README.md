# 1.4.13 build 50 — trial measurement

目的: 試用から有料契約へ移らない理由を今後分析できるように、契約とアプリ利用の結合キー・再生計測を追加する。ユーザーから計測改善のリリースを依頼された。

- 公開中の1.4.12 (48)、審査待ちの1.4.13 (49) を確認して作業開始。
- 1.4.13の既存契約検証修正を保持し、今回の計測変更を追加。
- HomeViewの別Issueの未公開変更は含めず、1.4.12の保存ソースを使用。
- 作業ディレクトリ: `/tmp/voiceyourtext-release-1.4.13-50`。
- ソース保存: `iOS/build/source-1.4.13-50.tar.gz` と `.json`。実サービス設定・鍵は除外。署名設定は含む。

## 変更内容

RevenueCat appUserIDから導出した仮名化キーをGA4 user_idに設定し、Firebase App Instance IDをRevenueCatへ同期。契約状態スナップショットと、TextInputView経由の再生要求・進行・失敗・停止・完了を記録する。本文・メールをイベントへ送信しない。

時刻が近いだけの推測結合は行わない。非再訪者の契約結果はRevenueCat履歴から取得する。過去データの欠損は埋まらない。PDF/NowPlaying等の未対応経路、Analytics未送信を未利用と扱わない。価格不満など主観的理由は計測のみで確定しない。

## 検証

- TextListeningTests 7件とPlaybackResumeTests 14件が成功。結果: `iOS/build/Issue163-Analytics-Final-20261107.xcresult`。
- 対象Swift 6ファイルのlintエラーなし。
- 分離ソースでの最初のarchiveはroot entitlementsのコピー漏れで失敗し、両entitlementsを補って再実行。
- 分離ソースのRelease archive成功。署名検証とbundle version 1.4.13 (50) の確認成功。
- 公開版でのGA4受信・RevenueCat属性の照合は公開後に必要。

## 提出状態

2026-11-07 23:59 JST にビルド50のアップロード成功。Delivery UUID: `e5667e3c-a149-44c8-ad0f-b2874a58d775`。Apple側の処理はVALIDになった。

最初のアップロードは分析用APIキーの権限不足（403）で失敗。既存リリースキーで再送成功。

2026-11-08 JST: ビルド49の申請を取り下げ、ビルド50へ差し替えて再提出成功（WAITING_FOR_REVIEW）。承認後自動公開（AFTER_APPROVAL）。既存の1.4.13のストア文言・スクリーンショットは保持。詳細は `submission.json` を参照。公開済みとは扱わず、到達確認は公開後に行う。

作業ツリーのビルド番号も50へ更新。既存の未コミット変更が多いため一括コミットは行わず、実際の配布ソースは上記スナップショット・SHA256で保存した。
