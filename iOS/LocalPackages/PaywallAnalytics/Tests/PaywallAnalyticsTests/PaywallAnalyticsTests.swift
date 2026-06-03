import XCTest
@testable import PaywallAnalytics

final class PaywallAnalyticsTests: XCTestCase {

    func test_paywallView_buildsPaywallViewEventWithSource() {
        let event = PaywallAnalyticsEvent.paywallView(source: .homeFileLimit)
        XCTAssertEqual(event.name, "paywall_view")
        XCTAssertEqual(event.parameters, ["source": "home_file_limit"])
    }

    func test_paywallView_eachSourceMapsToStableRawValue() {
        let expected: [PaywallSource: String] = [
            .homeFileLimit: "home_file_limit",
            .textCharLimit: "text_char_limit",
            .pdfPickerLimit: "pdf_picker_limit",
            .pdfSimpleLimit: "pdf_simple_limit",
            .pdfListLimit: "pdf_list_limit",
            .settings: "settings",
            .unknown: "unknown",
        ]
        for (source, raw) in expected {
            let event = PaywallAnalyticsEvent.paywallView(source: source)
            XCTAssertEqual(event.parameters["source"], raw, "\(source) の source 値が不一致")
        }
    }

    func test_rawSourceInit_knownValueResolves() {
        XCTAssertEqual(PaywallSource(rawSource: "settings"), .settings)
        XCTAssertEqual(PaywallSource(rawSource: "pdf_list_limit"), .pdfListLimit)
    }

    func test_rawSourceInit_unknownFallsBackToUnknown() {
        XCTAssertEqual(PaywallSource(rawSource: "garbage"), .unknown)
        XCTAssertEqual(PaywallSource(rawSource: ""), .unknown)
    }

    func test_allSourcesCovered() {
        // 導線を追加したらこのテストが落ちて追従漏れに気づける
        XCTAssertEqual(PaywallSource.allCases.count, 7)
    }
}
