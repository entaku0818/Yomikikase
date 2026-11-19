//
//  AppOpenAdManager.swift
//  VoiceYourText
//
//  App Open広告（起動時の全画面広告）の管理。
//
//  設計の前提（AdMob実測に基づく共通ルール）:
//   1. ロード待ちを必ず入れる。App Open広告の取得には1〜2秒かかるため、
//      SDK初期化直後に「未ロードなら即諦める」実装だと表示率が0.2%になる
//      （別アプリで実測）。ここでは上限4秒待つ。
//   2. 表示間隔のゲート。毎起動で出すのは体験を壊すので3回に1回。
//      （5回に1回だった 2026-09 は cold start が少なく月数回しか出なかったため 2026-10 に3回へ）
//   3. カウンタは専用キー（UserDefaultsManager.appOpenAdLaunchCount）。
//      他機能とキーを共有すると表示機会が消え、課金訴求まで誤爆する。
//   4. 課金ユーザーには出さない。
//   5. プリロードは「表示されうるユーザー」にだけ走らせる。
//      表示回でない起動ではロード要求自体を行わない（無駄打ちを防ぐ）。
//   6. バナーには手を加えない。
//
//  cold start のみを対象にしている理由:
//   このアプリは UIBackgroundModes: audio でバックグラウンド再生するため、
//   復帰時（warm foreground）に全画面広告を出すと再生中のリスニングを中断する。
//   平均セッション17.8分のヘビーユーザーが多く、中断の体験コストが広告収益に
//   見合わないと判断した。warm start に広げるには「再生中か」を表す全体状態が
//   必要で、それは別課題。
//

import FirebaseAnalytics
import GoogleMobileAds
import UIKit

/// 表示判定の純粋ロジック。SDKに依存しないのでユニットテストできる。
enum AppOpenAdGate {
    /// 何回の起動に1回表示するか（初期値。共通ルール2）
    static let defaultShowEveryNLaunches = 3

    /// この起動で App Open広告を表示すべきか。
    /// - Parameters:
    ///   - launchCount: インクリメント済みの起動回数（1始まり）
    ///   - isPremiumUser: 課金ユーザーかどうか
    ///   - hasCompletedOnboarding: オンボーディングを完了しているか
    ///   - showEveryNLaunches: 表示間隔
    static func shouldShow(
        launchCount: Int,
        isPremiumUser: Bool,
        hasCompletedOnboarding: Bool,
        showEveryNLaunches: Int = defaultShowEveryNLaunches
    ) -> Bool {
        // 共通ルール4: 課金ユーザーには出さない
        guard !isPremiumUser else { return false }
        // オンボーディング中に全画面広告を被せない
        guard hasCompletedOnboarding else { return false }
        guard showEveryNLaunches > 0 else { return false }
        guard launchCount > 0 else { return false }
        // 初回起動では出ない（launchCount=1 のとき 1 % 5 != 0）
        return launchCount % showEveryNLaunches == 0
    }
}

/// GADMobileAds.sharedInstance().start() を1回だけ実行し、完了を待てるようにする。
/// App Open広告は初期化完了前にロード要求しても取得できないため、明示的に待つ必要がある。
final class AdMobInitializer {
    static let shared = AdMobInitializer()

    private var startTask: Task<Void, Never>?

    private init() {}

    /// SDKの初期化を開始する（複数回呼んでも初回だけ実行される）
    func start() {
        guard startTask == nil else { return }
        startTask = Task {
            await withCheckedContinuation { continuation in
                GADMobileAds.sharedInstance().start { _ in
                    infoLog("Google Mobile Ads SDK initialized")
                    continuation.resume()
                }
            }
        }
    }

    /// 初期化完了まで待つ
    func waitUntilReady() async {
        start()
        await startTask?.value
    }
}

final class AppOpenAdManager: NSObject {
    static let shared = AppOpenAdManager()

    /// ロード待ちの上限（共通ルール1: 3〜5秒）
    private let loadTimeout: TimeInterval = 4.0
    /// ロード待ちのポーリング間隔
    private let pollInterval: TimeInterval = 0.1
    /// キャッシュしたAd の有効期限（AdMobの推奨は4時間）
    private let adExpirationInterval: TimeInterval = 4 * 60 * 60

    private var appOpenAd: GADAppOpenAd?
    private var loadTime: Date?
    private var isLoading = false
    private var isShowingAd = false
    /// SDKの表示コールバックに、この表示を開始した起動回数を引き継ぐ。
    private var presentationLaunchCount: Int?
    /// cold start の処理を二重に走らせない
    private var hasHandledColdStart = false

    private enum LoadOutcome {
        case ready
        case failed
        case timedOut
    }

    override private init() {
        super.init()
    }

    private var hasValidAd: Bool {
        guard appOpenAd != nil, let loadTime else { return false }
        return Date().timeIntervalSince(loadTime) < adExpirationInterval
    }

    /// 起動時に一度だけ呼ぶ。表示回であればロードを待って全画面広告を表示する。
    /// 表示回でなければロード要求すら行わない（共通ルール5）。
    /// - Returns: 表示を開始したか（起動時のレビュー依頼を被せないために使う）。実表示の計測はSDKのコールバックで行う。
    @MainActor
    @discardableResult
    func showAdOnColdStartIfEligible() async -> Bool {
        guard !AppDelegate.isRunningTests else { return false }
        guard !hasHandledColdStart else { return false }
        hasHandledColdStart = true

        // 共通ルール3: 専用キーのカウンタをインクリメント
        let launchCount = UserDefaultsManager.shared.appOpenAdLaunchCount + 1
        UserDefaultsManager.shared.appOpenAdLaunchCount = launchCount

        let isPremiumUser = UserDefaultsManager.shared.isPremiumUser
        let hasCompletedOnboarding = UserDefaultsManager.shared.hasCompletedOnboarding

        guard AppOpenAdGate.shouldShow(
            launchCount: launchCount,
            isPremiumUser: isPremiumUser,
            hasCompletedOnboarding: hasCompletedOnboarding
        ) else {
            let reason: String
            if isPremiumUser {
                reason = "premium"
            } else if !hasCompletedOnboarding {
                reason = "onboarding"
            } else {
                reason = "launch_gate"
            }
            debugLog("App open ad skipped (\(reason), launchCount=\(launchCount))")
            logSkipped(reason: reason, launchCount: launchCount)
            return false
        }

        let unitID = AdConfig.shared.appOpenAdUnitID
        guard !unitID.isEmpty else {
            errorLog("App open ad unit ID is empty - skipping")
            logSkipped(reason: "no_unit_id", launchCount: launchCount)
            return false
        }

        // 共通ルール1: SDK初期化を待ってからロードし、最大 loadTimeout 秒待つ
        await AdMobInitializer.shared.waitUntilReady()
        beginLoadIfNeeded(unitID: unitID, launchCount: launchCount)

        switch await waitForAd(timeout: loadTimeout) {
        case .ready:
            return present(launchCount: launchCount)
        case .failed:
            logSkipped(reason: "load_failed", launchCount: launchCount)
            return false
        case .timedOut:
            // 待機を終えてもSDKのロードは継続する。この起動で後追い表示はしない。
            debugLog("App open ad not ready within \(loadTimeout)s - skipping this launch")
            logSkipped(reason: "load_timeout", launchCount: launchCount)
            return false
        }
    }

    // MARK: - Load

    private func beginLoadIfNeeded(unitID: String, launchCount: Int) {
        guard !isLoading, !hasValidAd else { return }
        isLoading = true
        let loadStartedAt = Date()
        // アプリからの明示的なload呼び出しを数える。SDK・アダプタ内部の再試行は個別には数えない。
        Analytics.logEvent("app_open_ad_requested", parameters: ["launch_count": launchCount])

        GADAppOpenAd.load(withAdUnitID: unitID, request: GADRequest()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                let durationMilliseconds = Int(max(0, Date().timeIntervalSince(loadStartedAt) * 1_000))

                guard error == nil, let ad else {
                    if let error {
                        errorLog("App open ad failed to load: \(error.localizedDescription)")
                    }
                    self.logLoadFailure(error, launchCount: launchCount, durationMilliseconds: durationMilliseconds)
                    self.appOpenAd = nil
                    self.loadTime = nil
                    return
                }
                self.appOpenAd = ad
                self.loadTime = Date()
                Analytics.logEvent("app_open_ad_loaded", parameters: [
                    "launch_count": launchCount,
                    "load_duration_ms": durationMilliseconds
                ])
                debugLog("App open ad loaded")
            }
        }
    }

    /// ロード完了を最大 timeout 秒待ち、ロード失敗と待機時間超過を区別する。
    @MainActor
    private func waitForAd(timeout: TimeInterval) async -> LoadOutcome {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if hasValidAd {
                return .ready
            }
            if !isLoading {
                return .failed
            }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        if hasValidAd {
            return .ready
        }
        return isLoading ? .timedOut : .failed
    }

    // MARK: - Present

    @MainActor
    private func present(launchCount: Int) -> Bool {
        guard !isShowingAd, let ad = appOpenAd else { return false }

        // rootViewController に nil を渡すと、SDKがメインウィンドウの最前面の
        // ビューコントローラから表示する。
        do {
            try ad.canPresent(fromRootViewController: nil)
        } catch {
            errorLog("App open ad cannot be presented: \(error.localizedDescription)")
            logPresentationFailure(error, launchCount: launchCount, stage: "preflight")
            logSkipped(reason: "cannot_present", launchCount: launchCount)
            clearAd()
            return false
        }

        ad.fullScreenContentDelegate = self
        // 表示1回ごとの推定収益（AdMob の「インプレッション単位の広告収益」が有効なときだけ届く）
        ad.paidEventHandler = { adValue in
            Analytics.logEvent("ad_app_open_paid", parameters: [
                "launch_count": launchCount,
                "value": adValue.value.doubleValue,
                "currency": adValue.currencyCode,
                "precision": adValue.precision.rawValue
            ])
        }
        isShowingAd = true
        presentationLaunchCount = launchCount
        Analytics.logEvent("app_open_ad_present_attempt", parameters: ["launch_count": launchCount])
        ad.present(fromRootViewController: nil)
        return true
    }

    private func clearAd() {
        appOpenAd = nil
        loadTime = nil
        presentationLaunchCount = nil
    }

    private func logLoadFailure(_ error: Error?, launchCount: Int, durationMilliseconds: Int) {
        var parameters: [String: Any] = [
            "launch_count": launchCount,
            "load_duration_ms": durationMilliseconds
        ]
        if let error {
            let nsError = error as NSError
            parameters["error_code"] = nsError.code
            parameters["error_domain"] = nsError.domain
        } else {
            parameters["reason"] = "empty_response"
        }
        Analytics.logEvent("app_open_ad_load_failed", parameters: parameters)
    }

    private func logPresentationFailure(_ error: Error, launchCount: Int, stage: String) {
        let nsError = error as NSError
        Analytics.logEvent("app_open_ad_present_failed", parameters: [
            "launch_count": launchCount,
            "stage": stage,
            "error_code": nsError.code,
            "error_domain": nsError.domain
        ])
    }

    /// shownは実インプレッション、skippedはその起動で表示を開始しなかった理由として比較する。
    private func logSkipped(reason: String, launchCount: Int) {
        Analytics.logEvent(
            "app_open_ad_skipped",
            parameters: ["reason": reason, "launch_count": launchCount]
        )
    }
}

// MARK: - GADFullScreenContentDelegate

extension AppOpenAdManager: GADFullScreenContentDelegate {
    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        debugLog("App open ad recorded impression")
        guard let launchCount = presentationLaunchCount else {
            return
        }
        Analytics.logEvent("app_open_ad_shown", parameters: ["launch_count": launchCount])
    }

    func adDidRecordClick(_ ad: GADFullScreenPresentingAd) {
        debugLog("App open ad was clicked")
        guard let launchCount = presentationLaunchCount else {
            return
        }
        Analytics.logEvent("app_open_ad_click", parameters: ["launch_count": launchCount])
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        errorLog("App open ad failed to present: \(error.localizedDescription)")
        if let launchCount = presentationLaunchCount {
            logPresentationFailure(error, launchCount: launchCount, stage: "presentation")
        }
        isShowingAd = false
        clearAd()
    }

    func adWillDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        debugLog("App open ad will dismiss")
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        debugLog("App open ad dismissed")
        isShowingAd = false
        // 一度表示したAdは再利用できないので破棄する。
        // 次の表示回にあらためてロードする。
        clearAd()
    }
}
