//
//  AdmobBannerView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/03/22.

import FirebaseAnalytics
import GoogleMobileAds
import UIKit
import SwiftUI

/// バナーを置いている画面。広告枠は全画面で共通の1枠なので、
/// どの画面で表示・収益が出ているかはこの値で GA4 に送って分ける。
enum AdBannerPlacement: String {
    case home
    case myFiles = "my_files"
    case textInput = "text_input"
    case speech
    case settings
    case languageSettings = "language_settings"
    case pdfReader = "pdf_reader"
    case pdfPicker = "pdf_picker"
    case simplePDFPicker = "simple_pdf_picker"
    case pdfList = "pdf_list"
}

/// Measures the space offered by the parent, including iPad split views and sheet margins.
struct AdmobBannerView: View {
    @EnvironmentObject private var adConfig: AdConfig
    let placement: AdBannerPlacement
    @State private var availableWidth: CGFloat = 0

    var body: some View {
        let adSize = AdBannerLayout.adSize(for: availableWidth)
        let height = adSize?.size.height ?? GADAdSizeBanner.size.height
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                if let adSize, !AppDelegate.isRunningTests {
                    AdmobBannerContent(placement: placement, adSize: adSize, adUnitID: adConfig.bannerAdUnitID)
                        .frame(width: adSize.size.width, height: adSize.size.height)
                        // Late callbacks from a retired size must not reach the new request.
                        .id(AdBannerLayout.Identity(adSize: adSize, unitID: adConfig.bannerAdUnitID))
                }
            }
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.width
            } action: { width in
                availableWidth = width
            }
            .preference(key: AdBannerHeightPreferenceKey.self, value: height)
    }
}

struct AdBannerHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

enum AdBannerLayout {
    struct Identity: Hashable {
        let width: CGFloat
        let height: CGFloat
        let unitID: String

        init(adSize: GADAdSize, unitID: String) {
            width = adSize.size.width
            height = adSize.size.height
            self.unitID = unitID
        }
    }

    static func adSize(for width: CGFloat) -> GADAdSize? {
        guard width.isFinite, width >= 1 else {
            return nil
        }
        // Never ask for an ad wider than the available space due to fractional points.
        return GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width.rounded(.down))
    }
}

/// Wait for attachment so the presenter comes from this banner's window, not another scene.
final class AdmobBannerUIView: GADBannerView {
    var onAttach: ((AdmobBannerUIView) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else {
            return
        }
        rootViewController = window.rootViewController
        onAttach?(self)
    }
}

struct AdmobBannerContent: UIViewRepresentable {
    private enum Phase: String {
        case idle, loading, loaded, impressed, failed
    }

    let placement: AdBannerPlacement
    let adSize: GADAdSize
    let adUnitID: String

    func makeUIView(context: Context) -> AdmobBannerUIView {
        let view = AdmobBannerUIView(adSize: adSize)
        view.adUnitID = adUnitID
        view.delegate = context.coordinator
        view.onAttach = { [weak coordinator = context.coordinator] banner in
            coordinator?.loadIfNeeded(banner, adSize: banner.adSize)
        }
        view.paidEventHandler = { [weak coordinator = context.coordinator, weak view] adValue in
            guard let view else {
                return
            }
            coordinator?.log("ad_banner_paid", banner: view, parameters: [
                "value": adValue.value.doubleValue,
                "currency": adValue.currencyCode,
                "precision": adValue.precision.rawValue
            ])
        }
        return view
    }

    func updateUIView(_ uiView: AdmobBannerUIView, context: Context) {
        uiView.adUnitID = adUnitID
        guard uiView.window != nil else {
            uiView.adSize = adSize
            return
        }
        context.coordinator.loadIfNeeded(uiView, adSize: adSize)
    }

    static func dismantleUIView(_ uiView: AdmobBannerUIView, coordinator: Coordinator) {
        coordinator.abandonIfNeeded(uiView, reason: "view_removed")
        uiView.onAttach = nil
        uiView.paidEventHandler = nil
        uiView.delegate = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(placement: placement)
    }

    class Coordinator: NSObject, GADBannerViewDelegate {
        let placement: AdBannerPlacement
        private let logEvent: (String, [String: Any]) -> Void
        private let loadAd: (GADBannerView) -> Void
        private var requestedSize: CGSize?
        private var requestedUnitID: String?
        private var phase = Phase.idle
        private var requestStartedAt: Date?

        init(
            placement: AdBannerPlacement,
            logEvent: @escaping (String, [String: Any]) -> Void = {
                Analytics.logEvent($0, parameters: $1)
            },
            loadAd: @escaping (GADBannerView) -> Void = { $0.load(GADRequest()) }
        ) {
            self.placement = placement
            self.logEvent = logEvent
            self.loadAd = loadAd
        }

        func loadIfNeeded(_ banner: GADBannerView, adSize: GADAdSize) {
            guard requestedSize != adSize.size || requestedUnitID != banner.adUnitID else {
                return
            }
            abandonIfNeeded(banner, reason: "size_or_unit_changed")
            requestedSize = adSize.size
            requestedUnitID = banner.adUnitID
            banner.adSize = adSize
            phase = .loading
            requestStartedAt = Date()
            // Only explicit app requests are counted here. SDK automatic refresh requests
            // are not exposed by the delegate and must be read from AdMob reporting.
            log("ad_banner_requested", banner: banner, parameters: ["load_source": "app"])
            loadAd(banner)
        }

        func log(_ event: String, banner: GADBannerView, parameters: [String: Any] = [:]) {
            var values = parameters
            values["placement"] = placement.rawValue
            values["ad_width"] = Int(banner.adSize.size.width)
            values["ad_height"] = Int(banner.adSize.size.height)
            logEvent(event, values)
        }

        func abandonIfNeeded(_ banner: GADBannerView, reason: String) {
            if phase == .loading || phase == .loaded {
                log("ad_banner_abandoned", banner: banner, parameters: ["phase": phase.rawValue, "reason": reason])
            }
            phase = .idle
            requestStartedAt = nil
        }

        private func loadResultParameters() -> [String: Any] {
            guard let requestStartedAt else {
                return ["load_source": "sdk_refresh"]
            }
            return [
                "load_source": "app",
                "load_duration_ms": Int(max(0, Date().timeIntervalSince(requestStartedAt) * 1_000))
            ]
        }

        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            let parameters = loadResultParameters()
            if phase == .loaded {
                abandonIfNeeded(bannerView, reason: "refreshed_before_impression")
            }
            requestStartedAt = nil
            phase = .loaded
            log("ad_banner_loaded", banner: bannerView, parameters: parameters)
        }

        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            var parameters = loadResultParameters()
            let nsError = error as NSError
            parameters["error_code"] = nsError.code
            parameters["error_domain"] = nsError.domain
            log("ad_banner_load_failed", banner: bannerView, parameters: parameters)
            requestStartedAt = nil
            // A failed SDK refresh need not remove the previously loaded creative.
            if phase == .loading {
                phase = .failed
            }
        }

        func bannerViewDidRecordImpression(_ bannerView: GADBannerView) {
            phase = .impressed
            log("ad_banner_impression", banner: bannerView)
        }

        func bannerViewDidRecordClick(_ bannerView: GADBannerView) {
            log("ad_banner_click", banner: bannerView)
        }
    }
}
