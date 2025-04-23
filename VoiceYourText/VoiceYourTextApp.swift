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
import RevenueCat

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        Purchases.logLevel = .debug
        
        // 環境変数から取得したAPIキーを使用
        let apiKey = getRevenueCatAPIKey()
        Purchases.configure(withAPIKey: apiKey)
        
        // アプリ起動時にプレミアムステータスを確認
        Task {
            await PurchaseManager.shared.checkPremiumStatus()
        }
        
        return true
    }
    
    // RevenueCatのAPIキーを取得するメソッド
    private func getRevenueCatAPIKey() -> String {
        // Info.plistからAPIキーを取得
        if let apiKey = Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String,
           !apiKey.isEmpty {
            print("Using RevenueCat API key from Info.plist")
            return apiKey
        }
        
        // 環境変数から取得
        if let envAPIKey = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"],
           !envAPIKey.isEmpty {
            print("Using RevenueCat API key from environment variable")
            return envAPIKey
        }
        
        // フォールバックとしてConfigから読み込み
        print("Warning: Using hardcoded API key from Config. Consider setting up environment variables.")
        return Config.revenueCatAPIKey
    }
}

@main
struct VoiceYourTextApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isPremiumChecked = false

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
