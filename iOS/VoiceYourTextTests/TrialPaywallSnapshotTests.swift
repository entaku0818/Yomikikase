import StoreKit
import StoreKitTest
import SwiftUI
import XCTest
@testable import VoiceYourText

/// StoreKit Configuration（iOS/StoreKit/VoiceYourText.storekit）の商品を使ってプランカードを画像に書き出す目視確認用テスト。
/// 通常の CI では skip する。実行するとき:
///   TEST_RUNNER_TRIAL_PAYWALL_SNAPSHOT=1 xcodebuild test ... -only-testing:VoiceYourTextTests/TrialPaywallSnapshotTests -testLanguage ja
/// 画像は /tmp/voiceyourtext_trial_paywall/<言語>_{eligible,ineligible}.png に出力される。
@MainActor
final class TrialPaywallSnapshotTests: XCTestCase {
    private let monthlyID = "voiceNarrator_pro_Monthly"
    private let annualID = "voiceNarrator_pro_Annual"

    func testRenderTrialPaywall() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TRIAL_PAYWALL_SNAPSHOT"] == "1")

        let configURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("StoreKit/VoiceYourText.storekit")
        let session = try SKTestSession(contentsOf: configURL)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true

        let outputDir = URL(fileURLWithPath: "/tmp/voiceyourtext_trial_paywall")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let language = Bundle.main.preferredLocalizations.first ?? "unknown"

        // 未購入 = 導入オファー適格
        let eligible = try await loadPlans()
        XCTAssertEqual(eligible.monthly.displayedTrialDays, 7)
        XCTAssertEqual(eligible.annual.displayedTrialDays, 7)
        try render(eligible, to: outputDir.appendingPathComponent("\(language)_eligible.png"))

        // 購入済み = 同じサブスクグループで導入オファーを使用済み → 非適格
        let monthlyProducts = try await Product.products(for: [monthlyID])
        let monthlyProduct = try XCTUnwrap(monthlyProducts.first)
        let result = try await monthlyProduct.purchase()
        guard case .success(let verification) = result, case .verified(let transaction) = verification else {
            return XCTFail("購入に失敗: \(result)")
        }
        await transaction.finish()
        let ineligible = try await loadPlans()
        XCTAssertNil(ineligible.monthly.displayedTrialDays)
        XCTAssertNil(ineligible.annual.displayedTrialDays)
        try render(ineligible, to: outputDir.appendingPathComponent("\(language)_ineligible.png"))
    }

    private func loadPlans() async throws -> (monthly: SubscriptionPlanInfo, annual: SubscriptionPlanInfo) {
        let products = try await Product.products(for: [monthlyID, annualID])
        func plan(_ id: String, _ period: SubscriptionPlanInfo.BillingPeriod) async throws -> SubscriptionPlanInfo {
            let product = try XCTUnwrap(products.first { $0.id == id })
            let subscription = try XCTUnwrap(product.subscription)
            var trialDays: Int?
            if let offer = subscription.introductoryOffer, offer.paymentMode == .freeTrial {
                switch offer.period.unit {
                case .day:
                    trialDays = offer.period.value
                case .week:
                    trialDays = offer.period.value * 7
                default:
                    trialDays = nil
                }
            }
            return SubscriptionPlanInfo(
                name: product.displayName,
                price: product.displayPrice,
                period: period,
                trialDays: trialDays,
                isTrialEligible: await subscription.isEligibleForIntroOffer
            )
        }
        return (try await plan(monthlyID, .monthly), try await plan(annualID, .annual))
    }

    private func render(_ plans: (monthly: SubscriptionPlanInfo, annual: SubscriptionPlanInfo), to url: URL) throws {
        let view = VStack(spacing: 12) {
            AnnualPlanCard(monthlyPlan: plans.monthly, annualPlan: plans.annual, isLoading: false, isProcessing: false) {}
            MonthlyPlanCard(plan: plans.monthly, isLoading: false, isProcessing: false) {}
        }
        .padding()
        .frame(width: 393)
        .background(Color(.systemBackground))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        let data = try XCTUnwrap(renderer.uiImage?.pngData())
        try data.write(to: url)
    }
}
