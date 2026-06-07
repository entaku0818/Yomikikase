import SwiftUI

/// VoiceNarrator アプリ共通カラーシステム
///
/// デザイン方針:
/// - グラデーション不使用。ソリッドカラーのみ
/// - システムカラー（ダークモード自動対応）を優先
/// - アクセントは Indigo で統一（信頼感・落ち着き）
///
/// 「全画面が参照する唯一の色の出どころ」。`Color.indigo` / `Color.orange`
/// などの直書きは禁止し、必ず本 enum 経由で参照する。
/// 詳細: DesignSystem/tokens.md
enum AppTheme {

    // MARK: - Primary

    /// アクセント。再生ボタン・全アイコン・CTA・タブのアクティブ・進捗バー・選択中フィルタ。
    /// Asset Catalog の `AccentIndigo`（Light #4B47E0 / Dark #8B87FF）を参照。
    static let primary = Color("AccentIndigo")

    /// アイコン地・選択地に使う薄いアクセント。
    static let primarySoft = primary.opacity(0.12)

    /// アクセント上の文字・アイコン色。
    static let onPrimary = Color.white

    /// プライマリボタンのテキスト色（互換エイリアス）。
    static let primaryForeground = onPrimary

    // MARK: - Surfaces（システムカラー：ダーク自動対応）

    /// グループ背景。
    static let groupedBg = Color(.systemGroupedBackground)

    /// カード / セル。
    static let card = Color(.secondarySystemGroupedBackground)

    // MARK: - Badge

    /// おすすめバッジ背景（アクセントに統一）。
    static let badgeBackground = primary

    /// バッジテキスト。
    static let badgeForeground = onPrimary

    // MARK: - Card Border

    /// 年額カードのボーダー。
    static let annualCardBorder = primary.opacity(0.5)

    /// 月額カードのボーダー（控えめ・システムカラー）。
    static let monthlyCardBorder = Color(.separator)

    // MARK: - Secondary Action

    /// 月額プランボタンのテキスト。
    static let secondaryForeground = Color.primary
}
