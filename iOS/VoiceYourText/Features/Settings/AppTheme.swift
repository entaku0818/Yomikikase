import SwiftUI

/// VoiceNarrator アプリ共通カラーシステム
///
/// デザイン方針:
/// - グラデーション不使用。ソリッドカラーのみ
/// - システムカラー（ダークモード自動対応）を優先
/// - アクセントは Indigo で統一（信頼感・落ち着き）
enum AppTheme {

    // MARK: - Primary

    /// メインアクション（年額プランボタンなど）
    static let primary = Color.indigo

    /// プライマリボタンのテキスト色
    static let primaryForeground = Color.white

    // MARK: - Badge

    /// おすすめバッジ背景
    static let badgeBackground = Color.orange

    /// バッジテキスト
    static let badgeForeground = Color.white

    // MARK: - Card

    /// 年額カードのボーダー
    static let annualCardBorder = Color.indigo.opacity(0.5)

    /// 月額カードのボーダー（控えめ・システムカラー）
    static let monthlyCardBorder = Color(.separator)

    // MARK: - Secondary Action

    /// 月額プランボタンのテキスト
    static let secondaryForeground = Color.primary
}
