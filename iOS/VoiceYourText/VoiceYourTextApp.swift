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
    private static func getAdUnitID() -> String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2435281174" // テスト用広告ユニットID
        #else
        // 環境変数から取得
        if let envAdUnitID = ProcessInfo.processInfo.environment["ADMOB_BANNER_ID"],
           !envAdUnitID.isEmpty {
            print("Using AdMob banner ID from environment variable")
            return envAdUnitID
        }
        
        // 環境変数から取得できない場合はInfo.plistから取得
        if let adUnitID = Bundle.main.infoDictionary?["ADMOB_BANNER_ID"] as? String,
           !adUnitID.isEmpty {
            print("Using AdMob banner ID from Info.plist")
            return adUnitID
        }
        
        // 広告ユニットIDが見つからない場合はエラーメッセージを表示して終了
        fatalError("AdMob banner ID not found. Please set it in Info.plist or environment variable.")
        #endif
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
