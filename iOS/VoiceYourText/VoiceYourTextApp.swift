//
//  VoiceYourTextApp.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 25.11.2023.
//

import ComposableArchitecture
import SwiftUI
import UIKit
import FirebaseCore
import FirebaseCrashlytics
import RevenueCat
import GoogleSignIn

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        infoLog("App launching...")

        // Firebase初期化
        infoLog("Configuring Firebase...")
        FirebaseApp.configure()
        infoLog("Firebase configured successfully")

        // Crashlytics初期化
        infoLog("Configuring Crashlytics...")
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        infoLog("Crashlytics configured successfully")

        infoLog("Configuring RevenueCat...")
        Purchases.logLevel = .debug

        // 環境変数から取得したAPIキーを使用
        let apiKey = getRevenueCatAPIKey()
        infoLog("RevenueCat API key source: \(apiKey.isEmpty ? "NOT FOUND" : "Found")")
        Purchases.configure(withAPIKey: apiKey)
        infoLog("RevenueCat configured successfully")

        // アプリ起動時にプレミアムステータスを確認
        Task {
            infoLog("Checking premium status...")
            await PurchaseManager.shared.checkPremiumStatus()
            infoLog("Premium status check completed")
        }

        infoLog("App launch completed")
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    // RevenueCatのAPIキーを取得するメソッド
    // 優先順位: 1. 環境変数 → 2. Info.plist
    private func getRevenueCatAPIKey() -> String {

        // 1. 環境変数から取得（優先）
        if let envAPIKey = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"],
           !envAPIKey.isEmpty {
            debugLog("Using RevenueCat API key from environment variable")
            return envAPIKey
        }

        // 2. Info.plistからAPIキーを取得（フォールバック）
        if let apiKey = Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String,
           !apiKey.isEmpty {
            debugLog("Using RevenueCat API key from Info.plist")
            return apiKey
        }

        // APIキーが見つからない場合はエラーメッセージを表示して終了
        fatalError("RevenueCat API key not found. Please set it in Info.plist or environment variable.")
    }
}

// 広告設定を管理するクラス
class AdConfig: ObservableObject {
    static let shared = AdConfig()
    let bannerAdUnitID: String

    private init() {
        self.bannerAdUnitID = AdConfig.getAdUnitID()
    }

    // 広告ユニットIDを取得するメソッド
    // 優先順位: 1. 環境変数 → 2. Info.plist
    private static func getAdUnitID() -> String {

        // 1. 環境変数から取得（優先）
        if let envAdUnitID = ProcessInfo.processInfo.environment["ADMOB_BANNER_ID"],
           !envAdUnitID.isEmpty {
            debugLog("Using AdMob banner ID from environment variable")
            return envAdUnitID
        }

        // 2. Info.plistから取得（フォールバック）
        if let adUnitID = Bundle.main.infoDictionary?["ADMOB_BANNER_ID"] as? String,
           !adUnitID.isEmpty {
            debugLog("Using AdMob banner ID from Info.plist")
            return adUnitID
        }

        // 広告ユニットIDが見つからない場合はエラーメッセージを表示して終了
        fatalError("AdMob banner ID not found. Please set it in Info.plist or environment variable.")
    }
}

@main
struct VoiceYourTextApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isPremiumChecked = false
    @StateObject private var adConfig = AdConfig.shared

    let initialState = Speeches.State(
        speechList: IdentifiedArrayOf(uniqueElements: []),
        currentText: ""
    )

    var body: some Scene {
        WindowGroup {
            MainView(store:
                        Store(initialState: initialState) {
                Speeches()
            }
            )
            .environmentObject(adConfig)
            .onAppear {
                // UIアプリケーションデリゲートの初期化後にもう一度チェック
                if !isPremiumChecked {
                    isPremiumChecked = true
                    Task {
                        await PurchaseManager.shared.checkPremiumStatus()
                    }
                }
            }
        }
    }
}
