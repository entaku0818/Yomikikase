import Foundation

/// Paywall（課金画面）を開いた導線。
/// GA4 `paywall_view` イベントの `source` パラメータの単一の真実源。
///
/// MLX/KokoroSwift などに依存しないため、このパッケージは
/// `swift test` でシミュレータ不要・CIで実行できる。
public enum PaywallSource: String, Sendable, CaseIterable {
    /// ホーム: ファイル数上限ゲート
    case homeFileLimit = "home_file_limit"
    /// テキスト入力: 4,000文字上限ゲート
    case textCharLimit = "text_char_limit"
    /// PDFピッカー: PDF数上限ゲート
    case pdfPickerLimit = "pdf_picker_limit"
    /// シンプルPDFピッカー: ファイル数上限ゲート
    case pdfSimpleLimit = "pdf_simple_limit"
    /// シンプルPDFピッカー: 「プレミアムにアップグレード」リンク（上限に当たる前に自分で押したもの）
    case pdfSimpleUpgradeLink = "pdf_simple_upgrade_link"
    /// PDF一覧: PDF数上限ゲート
    case pdfListLimit = "pdf_list_limit"
    /// 設定画面からの導線
    case settings = "settings"
    /// キャラ音声: 読み上げ中に今月の上限に達したアラート
    case voicevoxQuota = "voicevox_quota"
    /// キャラ音声: 声を選ぶシート（プレミアム限定の声など）
    case voicevoxPicker = "voicevox_picker"
    /// キャラ音声: 設定画面のキャラ音声セクション
    case voicevoxSettings = "voicevox_settings"
    /// 自動の課金案内: オンボーディング完了直後に1回だけ出すトライアル案内
    case onboardingTrial = "onboarding_trial"
    /// 自動の課金案内: 非課金ユーザーに30日に1回、起動時に出すもの
    case monthlyPrompt = "monthly_prompt"
    /// 不明な導線（フォールバック）
    case unknown = "unknown"

    /// 文字列の source から `PaywallSource` を解決する。
    /// 未知の値は `.unknown` にフォールバックする。
    public init(rawSource: String) {
        self = PaywallSource(rawValue: rawSource) ?? .unknown
    }
}

/// Paywall 関連の Analytics イベントを構築する。
public enum PaywallAnalyticsEvent {
    /// Paywall 表示イベント名。
    public static let paywallViewName = "paywall_view"

    /// `paywall_view` イベントの (名前, パラメータ) を構築する。
    public static func paywallView(source: PaywallSource) -> (name: String, parameters: [String: String]) {
        (paywallViewName, ["source": source.rawValue])
    }

    /// 購入ボタンを押した結果
    public enum PurchaseResult: String, Sendable, CaseIterable {
        case success
        case cancelled
        case failed

        public var eventName: String { "subscription_purchase_\(rawValue)" }
    }

    /// `subscription_purchase_success` / `_cancelled` / `_failed` の (名前, パラメータ) を構築する。
    /// どの導線で開いたペイウォールで、トライアル対象の人が買った（やめた）のかを集計できるようにする。
    /// - Parameters:
    ///   - planType: `monthly` / `annual`
    ///   - isTrialEligible: 押したプランが無料トライアル対象だったか
    ///   - error: 失敗時のエラー内容（failed のときだけ載せる）
    public static func purchase(
        _ result: PurchaseResult,
        source: PaywallSource,
        planType: String,
        isTrialEligible: Bool,
        error: String? = nil
    ) -> (name: String, parameters: [String: String]) {
        var parameters = [
            "source": source.rawValue,
            "plan_type": planType,
            "trial_eligible": isTrialEligible ? "true" : "false",
        ]
        if result == .failed, let error {
            parameters["error"] = error
        }
        return (result.eventName, parameters)
    }
}
