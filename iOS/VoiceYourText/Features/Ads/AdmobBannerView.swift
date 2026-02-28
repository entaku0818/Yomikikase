//
//  AdmobBannerView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/03/22.

import GoogleMobileAds
import UIKit
import SwiftUI

struct AdmobBannerView: UIViewRepresentable {
    @EnvironmentObject private var adConfig: AdConfig

    func makeUIView(context: Context) -> GADBannerView {
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
         Coordinator()
     }

    class Coordinator: NSObject, GADBannerViewDelegate {

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
        }

        // 広告がクリックされた時
        func bannerViewDidRecordClick(_ bannerView: GADBannerView) {
            debugLog("Ad was clicked.")
        }
    }
}
