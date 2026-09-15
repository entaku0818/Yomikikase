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
import FirebaseAnalytics
import FirebaseCrashlytics
import FirebaseAppCheck
import RevenueCat
import GoogleMobileAds
import GoogleSignIn

class AppDelegate: UIResponder, UIApplicationDelegate {
    // ユニットテストのホストアプリとして起動された場合はtrue。
    // Firebase/RevenueCatの実初期化は実ネットワーク呼び出しを伴い、
    // テスト実行環境ではKeychainアクセス不可等で延々とリトライしハングするため回避する。
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        infoLog("App launching...")

        guard !Self.isRunningTests else {
            infoLog("Running under XCTest - skipping Firebase/RevenueCat initialization")
            return true
        }

        // 撤去済みクラウドTTSの残骸（完了しようのないジョブID・クラウド音声の選択）を捨てる
        CloudTTSCleanup.run()

        // App Checkのプロバイダは FirebaseApp.configure() より前に設定する必要がある。
        // Debugビルドはシミュレータ/実機ともApp Attestが使えないためDebugProviderを使う
        // （Firebase ConsoleのApp Check > デバッグトークンに登録が必要）。
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(VoiceYourTextAppCheckProviderFactory())
        #endif

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

        // アプリ起動時にプレミアムステータスを確認・GA4ユーザープロパティを設定
        Task {
            infoLog("Checking premium status...")
            await PurchaseManager.shared.checkPremiumStatus()
            infoLog("Premium status check completed")
        }
        let isPremium = UserDefaultsManager.shared.isPremiumUser
        Analytics.setUserProperty(isPremium ? "true" : "false", forName: "is_premium")

        // Google Mobile Ads SDK の明示初期化。
        // App Open広告は初期化完了前にロード要求しても取得できないため、
        // 起動直後に開始しておき AppOpenAdManager 側で完了を待つ。
        infoLog("Starting Google Mobile Ads SDK...")
        AdMobInitializer.shared.start()

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
        assertionFailure("RevenueCat API key not found. Please set it in Info.plist or environment variable.")
        return ""
    }
}

// 広告設定を管理するクラス
class AdConfig: ObservableObject {
    static let shared = AdConfig()
    let bannerAdUnitID: String
    let appOpenAdUnitID: String

    private init() {
        self.bannerAdUnitID = AdConfig.getAdUnitID(key: "ADMOB_BANNER_ID", label: "banner")
        self.appOpenAdUnitID = AdConfig.getAdUnitID(key: "ADMOB_APP_OPEN_ID", label: "app open")
    }

    // 広告ユニットIDを取得するメソッド
    // 優先順位: 1. 環境変数 → 2. Info.plist
    // Releaseビルドで本番IDが入っていることは、ビルドフェーズ
    // "Validate AdMob Ad Unit IDs"（scripts/validate_admob_ids.sh）が保証している。
    private static func getAdUnitID(key: String, label: String) -> String {

        // 1. 環境変数から取得（優先）
        if let envAdUnitID = ProcessInfo.processInfo.environment[key],
           !envAdUnitID.isEmpty {
            debugLog("Using AdMob \(label) ID from environment variable")
            return envAdUnitID
        }

        // 2. Info.plistから取得（フォールバック）
        if let adUnitID = Bundle.main.infoDictionary?[key] as? String,
           !adUnitID.isEmpty {
            debugLog("Using AdMob \(label) ID from Info.plist")
            return adUnitID
        }

        // 広告ユニットIDが見つからない場合はエラーメッセージを表示して終了
        assertionFailure("AdMob \(label) ID not found. Please set \(key) in Info.plist or environment variable.")
        return ""
    }
}

@main
struct VoiceYourTextApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isPremiumChecked = false
    @State private var showOnboarding = !UserDefaultsManager.shared.hasCompletedOnboarding
    @StateObject private var adConfig = AdConfig.shared

    let initialState = Speeches.State(
        speechList: IdentifiedArrayOf(uniqueElements: []),
        currentText: ""
    )

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "screenshots") {
                ScreenshotView()
            } else {
                mainContent
            }
            #else
            mainContent
            #endif
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        MainView(store:
                    Store(initialState: initialState) {
            Speeches()
        }
        )
        .environmentObject(adConfig)
        .onAppear {
            if !isPremiumChecked && !AppDelegate.isRunningTests {
                isPremiumChecked = true
                Task {
                    await PurchaseManager.shared.checkPremiumStatus()
                }
                // パーソナルボイスを選んだことがあるユーザーだけ認可を取り直す。
                // これをしないと speechVoices() に現れず、再生時に既定音声へ落ちる。
                PersonalVoiceAccess.requestIfNeeded()
            }
        }
        .task {
            // App Open広告（起動時の全画面広告）。
            // オンボーディング表示中は被せない。表示回でなければロード要求も行わない。
            guard !showOnboarding else { return }
            await AppOpenAdManager.shared.showAdOnColdStartIfEligible()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingSheetContainer(onComplete: { showOnboarding = false })
        }
    }
}

// Wrapper that holds the OnboardingReducer Store stable across parent re-renders
private struct OnboardingSheetContainer: View {
    @State private var store: StoreOf<OnboardingReducer>

    init(onComplete: @escaping @Sendable () -> Void) {
        _store = State(wrappedValue: Store(initialState: OnboardingReducer.State()) {
            Reduce { _, action in
                if case .delegate(.completed) = action {
                    onComplete()
                }
                return .none
            }
            OnboardingReducer()
        })
    }

    var body: some View {
        OnboardingView(store: store)
    }
}
