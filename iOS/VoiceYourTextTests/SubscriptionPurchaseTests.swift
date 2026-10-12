//
//  SubscriptionPurchaseTests.swift
//  VoiceYourTextTests
//
//  購入キャンセルをエラー扱いしないこと・復元で購入なしの文言（issue #157）
//  購入結果イベントに導線(source)とトライアル対象かを載せること（issue #158）
//

import XCTest
import StoreKit
import RevenueCat
import Dependencies
@testable import VoiceYourText

@MainActor
final class SubscriptionPurchaseTests: XCTestCase {

    // MARK: - キャンセル判定

    func test_RevenueCatのキャンセルエラーはキャンセルと判定すること() {
        XCTAssertTrue(PurchaseOutcome.isCancellation(ErrorCode.purchaseCancelledError))
        XCTAssertTrue(PurchaseOutcome.isCancellation(ErrorCode.purchaseCancelledError as NSError))
    }

    func test_StoreKitのキャンセルはキャンセルと判定すること() {
        XCTAssertTrue(PurchaseOutcome.isCancellation(SKError(.paymentCancelled)))
        XCTAssertTrue(PurchaseOutcome.isCancellation(StoreKitError.userCancelled))
    }

    func test_キャンセル以外のエラーはキャンセルと判定しないこと() {
        XCTAssertFalse(PurchaseOutcome.isCancellation(ErrorCode.networkError))
        XCTAssertFalse(PurchaseOutcome.isCancellation(ErrorCode.paymentPendingError))
        XCTAssertFalse(PurchaseOutcome.isCancellation(SKError(.paymentInvalid)))
        XCTAssertFalse(PurchaseOutcome.isCancellation(PurchaseManager.PurchaseError.purchaseFailed))
        XCTAssertFalse(PurchaseOutcome.isCancellation(URLError(.notConnectedToInternet)))
    }

    // MARK: - SubscriptionViewModel

    private func makeViewModel(
        _ purchaseManager: FakePurchaseManager,
        events: LockIsolated<[String]>,
        parameters: LockIsolated<[String: Any]?> = LockIsolated(nil)
    ) -> SubscriptionViewModel {
        withDependencies {
            $0.analytics = AnalyticsClient(
                logEvent: { name, params in
                    events.withValue { $0.append(name) }
                    parameters.setValue(params)
                },
                setUserProperty: { _, _ in }
            )
        } operation: {
            SubscriptionViewModel(purchaseManager: purchaseManager)
        }
    }

    func test_購入をキャンセルしたらアラートを出さずcancelledを送ること() async {
        let events = LockIsolated<[String]>([])
        let viewModel = makeViewModel(FakePurchaseManager(purchase: { .cancelled }), events: events)

        let result = await viewModel.handlePurchase(planType: .monthly)

        XCTAssertNil(result)
        XCTAssertEqual(events.value, ["subscription_purchase_cancelled"])
        XCTAssertFalse(viewModel.isProcessing)
    }

    func test_購入結果イベントに導線とトライアル対象かを載せること() async {
        let events = LockIsolated<[String]>([])
        let parameters = LockIsolated<[String: Any]?>(nil)
        let viewModel = makeViewModel(FakePurchaseManager(purchase: { .cancelled }), events: events, parameters: parameters)
        viewModel.annualPlan = SubscriptionPlanInfo(
            name: "年額", price: "¥5,000", priceValue: 5000, period: .annual, trialDays: 7, isTrialEligible: true
        )

        _ = await viewModel.handlePurchase(planType: .annual, source: .voicevoxQuota)

        XCTAssertEqual(events.value, ["subscription_purchase_cancelled"])
        XCTAssertEqual(parameters.value?["source"] as? String, "voicevox_quota")
        XCTAssertEqual(parameters.value?["plan_type"] as? String, "annual")
        XCTAssertEqual(parameters.value?["trial_eligible"] as? String, "true")
    }

    func test_購入成功で完了のアラートを返すこと() async {
        let events = LockIsolated<[String]>([])
        let viewModel = makeViewModel(FakePurchaseManager(purchase: { .purchased }), events: events)

        let result = await viewModel.handlePurchase(planType: .annual)

        XCTAssertEqual(result?.success, true)
        XCTAssertEqual(events.value, ["subscription_purchase_success"])
    }

    func test_本当の失敗はfailedを送ってエラーを表示すること() async {
        let events = LockIsolated<[String]>([])
        let viewModel = makeViewModel(
            FakePurchaseManager(purchase: { throw PurchaseManager.PurchaseError.purchaseFailed }),
            events: events
        )

        let result = await viewModel.handlePurchase(planType: .monthly)

        XCTAssertEqual(result?.success, false)
        XCTAssertEqual(events.value, ["subscription_purchase_failed"])
    }

    func test_復元で購入履歴が無ければ見つからないと表示すること() async {
        let events = LockIsolated<[String]>([])
        let viewModel = makeViewModel(FakePurchaseManager(restore: { false }), events: events)

        let result = await viewModel.handleRestore()

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.title, String(localized: "購入履歴が見つかりません"))
        XCTAssertEqual(events.value, ["subscription_restore_failed"])
    }

    func test_復元で購入が見つかれば完了を表示すること() async {
        let events = LockIsolated<[String]>([])
        let viewModel = makeViewModel(FakePurchaseManager(restore: { true }), events: events)

        let result = await viewModel.handleRestore()

        XCTAssertTrue(result.success)
        XCTAssertEqual(events.value, ["subscription_restore_success"])
    }
}

private final class FakePurchaseManager: PurchaseManagerProtocol {
    let purchase: () throws -> PurchaseOutcome
    let restore: () throws -> Bool

    init(
        purchase: @escaping () throws -> PurchaseOutcome = { .purchased },
        restore: @escaping () throws -> Bool = { false }
    ) {
        self.purchase = purchase
        self.restore = restore
    }

    func fetchProPlan() async throws -> (name: String, price: String) { ("Pro", "¥500") }
    func fetchAllPlans() async throws -> (monthly: SubscriptionPlanInfo?, annual: SubscriptionPlanInfo?) { (nil, nil) }
    func purchasePro() async throws -> PurchaseOutcome { try purchase() }
    func purchasePro(planType: PurchaseManager.PlanType) async throws -> PurchaseOutcome { try purchase() }
    func restorePurchases() async throws -> Bool { try restore() }
    func checkPremiumStatus() async {}
}
