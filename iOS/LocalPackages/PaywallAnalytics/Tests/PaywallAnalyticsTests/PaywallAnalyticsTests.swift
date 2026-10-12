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
            .pdfSimpleUpgradeLink: "pdf_simple_upgrade_link",
            .pdfListLimit: "pdf_list_limit",
            .settings: "settings",
            .voicevoxQuota: "voicevox_quota",
            .voicevoxPicker: "voicevox_picker",
            .voicevoxSettings: "voicevox_settings",
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
        XCTAssertEqual(PaywallSource.allCases.count, 11)
    }

    func test_rawSourceInit_voicevoxSourcesNoLongerFallBackToUnknown() {
        XCTAssertEqual(PaywallSource(rawSource: "voicevox_quota"), .voicevoxQuota)
        XCTAssertEqual(PaywallSource(rawSource: "voicevox_picker"), .voicevoxPicker)
        XCTAssertEqual(PaywallSource(rawSource: "voicevox_settings"), .voicevoxSettings)
    }

    // MARK: - 購入結果イベント

    func test_purchase_success_carriesSourcePlanAndTrialEligibility() {
        let event = PaywallAnalyticsEvent.purchase(.success, source: .voicevoxQuota, planType: "annual", isTrialEligible: true)
        XCTAssertEqual(event.name, "subscription_purchase_success")
        XCTAssertEqual(event.parameters, [
            "source": "voicevox_quota",
            "plan_type": "annual",
            "trial_eligible": "true",
        ])
    }

    func test_purchase_cancelled_hasOwnEventNameAndSource() {
        let event = PaywallAnalyticsEvent.purchase(.cancelled, source: .settings, planType: "monthly", isTrialEligible: false, error: "ignored")
        XCTAssertEqual(event.name, "subscription_purchase_cancelled")
        XCTAssertEqual(event.parameters, [
            "source": "settings",
            "plan_type": "monthly",
            "trial_eligible": "false",
        ])
    }

    func test_purchase_failed_includesError() {
        let event = PaywallAnalyticsEvent.purchase(.failed, source: .homeFileLimit, planType: "monthly", isTrialEligible: true, error: "network")
        XCTAssertEqual(event.name, "subscription_purchase_failed")
        XCTAssertEqual(event.parameters["error"], "network")
        XCTAssertEqual(event.parameters["source"], "home_file_limit")
    }
}
