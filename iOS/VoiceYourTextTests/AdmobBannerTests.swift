import GoogleMobileAds
import SwiftUI
import XCTest
@testable import VoiceYourText

@MainActor
final class AdmobBannerTests: XCTestCase {
    private final class Events {
        var values: [(name: String, parameters: [String: Any])] = []
        var loads = 0

        func coordinator() -> AdmobBannerContent.Coordinator {
            AdmobBannerContent.Coordinator(
                placement: .pdfReader,
                logEvent: { self.values.append(($0, $1)) },
                loadAd: { _ in self.loads += 1 }
            )
        }
    }

    private func banner() -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = "test-unit"
        return banner
    }

    func testZeroAndInvalidWidthsDoNotProduceAdSizes() {
        for width: CGFloat in [0, -1, .infinity, .nan, 0.5] {
            XCTAssertNil(AdBannerLayout.adSize(for: width))
        }
    }

    func testBannerFitsNarrowAndWideContainers() throws {
        for width: CGFloat in [320.75, 375, 768, 1024] {
            let size = try XCTUnwrap(AdBannerLayout.adSize(for: width))
            XCTAssertLessThanOrEqual(size.size.width, width)
            XCTAssertGreaterThan(size.size.height, 0)
            XCTAssertEqual(size.size.width, width.rounded(.down))
        }
    }

    func testHostedBannerHeightMatchesSDKForItsContainerWidth() throws {
        let width: CGFloat = 768
        let expected = try XCTUnwrap(AdBannerLayout.adSize(for: width))
        var measuredHeight: CGFloat = 0
        let host = UIHostingController(rootView: AdmobBannerView(placement: .home)
            .environmentObject(AdConfig.shared)
            .frame(width: width)
            .onPreferenceChange(AdBannerHeightPreferenceKey.self) { measuredHeight = $0 }
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 600))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let deadline = Date().addingTimeInterval(3)
        while measuredHeight != expected.size.height && Date() < deadline {
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertEqual(measuredHeight, expected.size.height)
    }

    func testSwiftUIUpdatesDoNotReloadUnchangedBanner() {
        let events = Events()
        let coordinator = events.coordinator()
        let banner = banner()

        coordinator.loadIfNeeded(banner, adSize: GADAdSizeBanner)
        coordinator.loadIfNeeded(banner, adSize: GADAdSizeBanner)
        coordinator.bannerViewDidReceiveAd(banner)
        coordinator.loadIfNeeded(banner, adSize: GADAdSizeBanner)

        XCTAssertEqual(events.loads, 1)
        XCTAssertEqual(events.values.map(\.name), ["ad_banner_requested", "ad_banner_loaded"])
        XCTAssertEqual(events.values.last?.parameters["load_source"] as? String, "app")
        XCTAssertEqual(events.values.last?.parameters["placement"] as? String, "pdf_reader")
    }

    func testResizeReplacesPendingAdAndRequestsMatchingSizeOnce() throws {
        let events = Events()
        let coordinator = events.coordinator()
        let banner = banner()
        coordinator.loadIfNeeded(banner, adSize: GADAdSizeBanner)
        coordinator.bannerViewDidReceiveAd(banner)

        let wideSize = try XCTUnwrap(AdBannerLayout.adSize(for: 768))
        coordinator.loadIfNeeded(banner, adSize: wideSize)
        coordinator.loadIfNeeded(banner, adSize: wideSize)

        XCTAssertEqual(events.loads, 2)
        XCTAssertEqual(banner.adSize.size, wideSize.size)
        let abandoned = try XCTUnwrap(events.values.first { $0.name == "ad_banner_abandoned" })
        XCTAssertEqual(abandoned.parameters["phase"] as? String, "loaded")
        XCTAssertEqual(abandoned.parameters["reason"] as? String, "size_or_unit_changed")
        XCTAssertEqual(events.values.last?.parameters["ad_width"] as? Int, 768)
    }

    func testLeavingBeforeLoadAndBeforeImpressionAreDistinguished() throws {
        for loaded in [false, true] {
            let events = Events()
            let coordinator = events.coordinator()
            let banner = banner()
            coordinator.loadIfNeeded(banner, adSize: GADAdSizeBanner)
            if loaded {
                coordinator.bannerViewDidReceiveAd(banner)
            }
            coordinator.abandonIfNeeded(banner, reason: "view_removed")
            coordinator.abandonIfNeeded(banner, reason: "view_removed")

            let abandoned = events.values.filter { $0.name == "ad_banner_abandoned" }
            XCTAssertEqual(abandoned.count, 1)
            XCTAssertEqual(abandoned.first?.parameters["phase"] as? String, loaded ? "loaded" : "loading")
            XCTAssertFalse(events.values.contains { $0.name == "ad_banner_impression" })
        }
    }

    func testDisplayedAdIsNotCountedAsAbandonedOnExit() {
        let events = Events()
        let coordinator = events.coordinator()
        let banner = banner()
        coordinator.loadIfNeeded(banner, adSize: GADAdSizeBanner)
        coordinator.bannerViewDidReceiveAd(banner)
        coordinator.bannerViewDidRecordImpression(banner)
        coordinator.abandonIfNeeded(banner, reason: "view_removed")

        XCTAssertEqual(events.values.filter { $0.name == "ad_banner_impression" }.count, 1)
        XCTAssertFalse(events.values.contains { $0.name == "ad_banner_abandoned" })
    }

    func testLoadFailureRecordsOnlyStableErrorFields() throws {
        let events = Events()
        let coordinator = events.coordinator()
        let banner = banner()
        coordinator.loadIfNeeded(banner, adSize: GADAdSizeBanner)
        coordinator.bannerView(banner, didFailToReceiveAdWithError: NSError(
            domain: "com.google.admob", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Private diagnostic text"]
        ))
        coordinator.abandonIfNeeded(banner, reason: "view_removed")

        let failed = try XCTUnwrap(events.values.last)
        XCTAssertEqual(failed.name, "ad_banner_load_failed")
        XCTAssertEqual(failed.parameters["error_code"] as? Int, 1)
        XCTAssertEqual(failed.parameters["error_domain"] as? String, "com.google.admob")
        XCTAssertFalse(failed.parameters.values.contains { ($0 as? String) == "Private diagnostic text" })
    }

    func testAutomaticRefreshDoesNotCreateAnAppRequestOrLosePendingImpression() throws {
        let events = Events()
        let coordinator = events.coordinator()
        let banner = banner()
        coordinator.loadIfNeeded(banner, adSize: GADAdSizeBanner)
        coordinator.bannerViewDidReceiveAd(banner)
        coordinator.bannerView(banner, didFailToReceiveAdWithError: NSError(domain: "admob", code: 1))
        coordinator.abandonIfNeeded(banner, reason: "view_removed")

        let failed = try XCTUnwrap(events.values.first { $0.name == "ad_banner_load_failed" })
        XCTAssertEqual(failed.parameters["load_source"] as? String, "sdk_refresh")
        XCTAssertNil(failed.parameters["load_duration_ms"])
        XCTAssertEqual(events.values.last?.parameters["phase"] as? String, "loaded")
        XCTAssertEqual(events.loads, 1)
    }
}
