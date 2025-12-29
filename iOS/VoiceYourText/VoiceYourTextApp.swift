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
        infoLog("App launching...")

        // Firebase初期化（Objective-C例外をキャッチ）
        infoLog("Configuring Firebase...")
        var firebaseError: NSError?
        let success = ObjCExceptionCatcher.catchException(withBlock: {
            FirebaseApp.configure()
        }, error: &firebaseError)

        if success {
            infoLog("Firebase configured successfully")
        } else {
            let errorMessage = firebaseError?.localizedDescription ?? "Unknown error"
            let exceptionName = firebaseError?.userInfo["ExceptionName"] as? String ?? "Unknown"
            let exceptionReason = firebaseError?.userInfo["ExceptionReason"] as? String ?? "Unknown"
            errorLog("Firebase configuration failed!")
            errorLog("Exception: \(exceptionName)")
            errorLog("Reason: \(exceptionReason)")
            errorLog("Error: \(errorMessage)")
        }

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

    // RevenueCatのAPIキーを取得するメソッド
    // 優先順位: 1. 環境変数 → 2. Info.plist
    private func getRevenueCatAPIKey() -> String {

        // 1. 環境変数から取得（優先）
        if let envAPIKey = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"],
           !envAPIKey.isEmpty {
            print("Using RevenueCat API key from environment variable")
            return envAPIKey
        }

        // 2. Info.plistからAPIキーを取得（フォールバック）
        if let apiKey = Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String,
           !apiKey.isEmpty {
            print("Using RevenueCat API key from Info.plist")
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
            print("Using AdMob banner ID from environment variable")
            return envAdUnitID
        }

        // 2. Info.plistから取得（フォールバック）
        if let adUnitID = Bundle.main.infoDictionary?["ADMOB_BANNER_ID"] as? String,
           !adUnitID.isEmpty {
            print("Using AdMob banner ID from Info.plist")
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
