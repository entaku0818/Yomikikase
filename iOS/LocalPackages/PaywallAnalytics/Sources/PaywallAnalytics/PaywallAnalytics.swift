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
    /// PDF一覧: PDF数上限ゲート
    case pdfListLimit = "pdf_list_limit"
    /// 設定画面からの導線
    case settings = "settings"
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
}
