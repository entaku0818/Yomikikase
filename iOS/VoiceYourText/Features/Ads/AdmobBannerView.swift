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

struct AdmobBannerView: UIViewRepresentable {
    @EnvironmentObject private var adConfig: AdConfig
    let placement: AdBannerPlacement

    func makeUIView(context: Context) -> GADBannerView {
        // テスト中は広告を読み込まない。ScreenshotGeneratorTests の ImageRenderer は
        // 幅0高さ0で描くため、AdMob が "Invalid ad width or height" のあと約2分固まり、
        // そのとき実行中のテストが時間超過で落ちる（CI の不定期な失敗の原因）
        guard !AppDelegate.isRunningTests else {
            return GADBannerView(adSize: GADAdSizeBanner)
        }

        // 画面の幅を取得
        let screenWidth = UIScreen.main.bounds.width

        // バナーサイズを画面幅に合わせる
        let adaptiveSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(screenWidth)

        let view = GADBannerView(adSize: adaptiveSize)

        view.adUnitID = adConfig.bannerAdUnitID

        // iOS 13以降での推奨方法
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            view.rootViewController = rootViewController
        }

        view.delegate = context.coordinator
        // 表示1回ごとの推定収益（AdMob の「インプレッション単位の広告収益」が有効なときだけ届く）
        let placement = placement
        view.paidEventHandler = { adValue in
            Analytics.logEvent("ad_banner_paid", parameters: [
                "placement": placement.rawValue,
                "value": adValue.value.doubleValue,
                "currency": adValue.currencyCode,
                "precision": adValue.precision.rawValue
            ])
        }

        // 非同期で広告を読み込む（画面表示をブロックしない）
        DispatchQueue.global(qos: .utility).async {
            let request = GADRequest()
            DispatchQueue.main.async {
                view.load(request)
            }
        }

        return view
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        // 広告のリフレッシュは自動的に行われるため、手動での再読み込みは不要
    }

    // Adding the Coordinator for delegate handling
     func makeCoordinator() -> Coordinator {
         Coordinator(placement: placement)
     }

    class Coordinator: NSObject, GADBannerViewDelegate {
        let placement: AdBannerPlacement

        init(placement: AdBannerPlacement) {
            self.placement = placement
        }

        // 広告受信時
        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            debugLog("adUnitID: \(bannerView.adUnitID ?? "")")
            debugLog("Ad received successfully.")
        }

        // 広告受信失敗時
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            errorLog("Failed to load ad with error: \(error.localizedDescription)")
            debugLog("adUnitID: \(bannerView.adUnitID ?? "")")
        }

        // インプレッションが記録された時
        func bannerViewDidRecordImpression(_ bannerView: GADBannerView) {
            debugLog("Impression has been recorded for the ad.")
            Analytics.logEvent("ad_banner_impression", parameters: ["placement": placement.rawValue])
        }

        // 広告がクリックされた時
        func bannerViewDidRecordClick(_ bannerView: GADBannerView) {
            debugLog("Ad was clicked.")
            Analytics.logEvent("ad_banner_click", parameters: ["placement": placement.rawValue])
        }
    }
}
