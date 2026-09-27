import XCTest
@testable import VoiceYourText

final class SubscriptionPlanPresentationTests: XCTestCase {

    private func plan(
        period: SubscriptionPlanInfo.BillingPeriod = .monthly,
        price: String = "¥300",
        priceValue: Decimal = 300,
        trialDays: Int? = 7,
        isTrialEligible: Bool = true
    ) -> SubscriptionPlanInfo {
        SubscriptionPlanInfo(
            name: "Pro",
            price: price,
            priceValue: priceValue,
            period: period,
            trialDays: trialDays,
            isTrialEligible: isTrialEligible
        )
    }

    // MARK: - 表示分岐

    func testEligibleMonthlyShowsFreeTrial() {
        let presentation = SubscriptionPlanPresentation(plan: plan(), fallbackPeriod: .monthly)

        XCTAssertEqual(presentation.callToAction, .startFreeTrial)
        XCTAssertEqual(
            presentation.trialTerms,
            .init(days: 7, priceAfterTrial: "¥300", period: .monthly)
        )
    }

    func testEligibleAnnualShowsFreeTrialWithAnnualPrice() {
        let presentation = SubscriptionPlanPresentation(
            plan: plan(period: .annual, price: "¥2,200"),
            fallbackPeriod: .annual
        )

        XCTAssertEqual(presentation.callToAction, .startFreeTrial)
        XCTAssertEqual(
            presentation.trialTerms,
            .init(days: 7, priceAfterTrial: "¥2,200", period: .annual)
        )
    }

    func testIneligibleUserSeesRegularPurchase() {
        let monthly = SubscriptionPlanPresentation(plan: plan(isTrialEligible: false), fallbackPeriod: .monthly)
        XCTAssertEqual(monthly.callToAction, .purchase(.monthly))
        XCTAssertNil(monthly.trialTerms)

        let annual = SubscriptionPlanPresentation(
            plan: plan(period: .annual, isTrialEligible: false),
            fallbackPeriod: .annual
        )
        XCTAssertEqual(annual.callToAction, .purchase(.annual))
        XCTAssertNil(annual.trialTerms)
    }

    func testProductWithoutTrialSeesRegularPurchaseEvenIfEligible() {
        let presentation = SubscriptionPlanPresentation(plan: plan(trialDays: nil), fallbackPeriod: .monthly)

        XCTAssertEqual(presentation.callToAction, .purchase(.monthly))
        XCTAssertNil(presentation.trialTerms)
    }

    func testZeroDayTrialIsNotAdvertised() {
        let presentation = SubscriptionPlanPresentation(plan: plan(trialDays: 0), fallbackPeriod: .monthly)

        XCTAssertEqual(presentation.callToAction, .purchase(.monthly))
        XCTAssertNil(presentation.trialTerms)
    }

    func testMissingPlanFallsBackToRegularPurchase() {
        XCTAssertEqual(
            SubscriptionPlanPresentation(plan: nil, fallbackPeriod: .annual).callToAction,
            .purchase(.annual)
        )
        XCTAssertNil(SubscriptionPlanPresentation(plan: nil, fallbackPeriod: .monthly).trialTerms)
    }

    // MARK: - 年額の割引率

    func testAnnualSavingsIsComputedFromRealPrices() {
        // 日本: ¥500/月 vs ¥5,000/年 → 12か月分 ¥6,000 に対して約17%
        XCTAssertEqual(
            SubscriptionPlanInfo.annualSavingsPercent(
                monthly: plan(period: .monthly, priceValue: 500),
                annual: plan(period: .annual, priceValue: 5000)
            ),
            17
        )
        // 米国: $2.99/月 vs $29.99/年 → 約16%
        XCTAssertEqual(
            SubscriptionPlanInfo.annualSavingsPercent(
                monthly: plan(period: .monthly, priceValue: Decimal(string: "2.99")!),
                annual: plan(period: .annual, priceValue: Decimal(string: "29.99")!)
            ),
            16
        )
    }

    func testAnnualSavingsIsNilWhenNotCheaperOrPriceMissing() {
        // 年額のほうが高い/同じなら割引として見せない
        XCTAssertNil(SubscriptionPlanInfo.annualSavingsPercent(
            monthly: plan(period: .monthly, priceValue: 500),
            annual: plan(period: .annual, priceValue: 6000)
        ))
        // 価格が取れないとき（フォールバック経路）
        XCTAssertNil(SubscriptionPlanInfo.annualSavingsPercent(
            monthly: plan(period: .monthly, priceValue: 0),
            annual: plan(period: .annual, priceValue: 5000)
        ))
        XCTAssertNil(SubscriptionPlanInfo.annualSavingsPercent(monthly: nil, annual: plan(period: .annual, priceValue: 5000)))
    }

    // MARK: - 文言

    func testTrialTextsContainDynamicPriceAndDays() {
        let terms = SubscriptionPlanPresentation.TrialTerms(days: 7, priceAfterTrial: "$2.99", period: .monthly)

        XCTAssertTrue(terms.headline.contains("7"))
        XCTAssertTrue(terms.headline.contains("$2.99"))
        XCTAssertTrue(terms.renewalNotice.contains("$2.99"))
        XCTAssertTrue(terms.renewalNotice.contains("24"))
    }

    /// 新しく追加したトライアル文言が ja / en 両方に翻訳されていること
    func testTrialStringsAreLocalizedInJapaneseAndEnglish() throws {
        let keys = [
            "%lld日間無料、その後 %@/月",
            "%lld日間無料、その後 %@/年",
            "無料期間の終了後は自動的に %@/月 で更新され、Apple ID に課金されます。",
            "無料期間の終了後は自動的に %@/年 で更新され、Apple ID に課金されます。",
            "いつでもキャンセル可能です。無料期間終了の24時間前までに「設定」アプリのサブスクリプションから解約すれば料金はかかりません。",
            "無料で試す",
            "%lld日間無料・約38%%お得",
            "読み上げをもっと快適に"
        ]
        let appBundle = Bundle(for: SubscriptionViewModel.self)
        let missing = "__MISSING__"

        for language in ["ja", "en"] {
            let path = try XCTUnwrap(appBundle.path(forResource: language, ofType: "lproj"), "\(language).lproj がない")
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in keys {
                let value = bundle.localizedString(forKey: key, value: missing, table: nil)
                XCTAssertNotEqual(value, missing, "\(language) に \(key) がない")
                if language == "en" {
                    XCTAssertNotEqual(value, key, "en が未翻訳: \(key)")
                }
            }
        }
    }
}
