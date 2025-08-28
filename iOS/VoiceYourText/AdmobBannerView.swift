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
        view.load(GADRequest())
        return view
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
    }

    // Adding the Coordinator for delegate handling
     func makeCoordinator() -> Coordinator {
         Coordinator()
     }

    class Coordinator: NSObject, GADBannerViewDelegate {

        // 広告受信時
        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            print("adUnitID: \(bannerView.adUnitID)")
            print("Ad received successfully.")

        }

        // 広告受信失敗時
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("Failed to load ad with error: \(error.localizedDescription)")
            print("adUnitID: \(bannerView.adUnitID)")

        }

        // インプレッションが記録された時
        func bannerViewDidRecordImpression(_ bannerView: GADBannerView) {
            print("Impression has been recorded for the ad.")
        }

        // 広告がクリックされた時
        func bannerViewDidRecordClick(_ bannerView: GADBannerView) {
            print("Ad was clicked.")
        }
    }
}
