import Foundation

/// Paywall に表示するプラン情報。StoreProduct から取得した値だけを持つ（価格はハードコードしない）。
struct SubscriptionPlanInfo: Equatable {
    enum BillingPeriod: Equatable {
        case monthly
        case annual
    }

    let name: String
    /// StoreProduct.localizedPriceString（例: ¥300）
    let price: String
    let period: BillingPeriod
    /// 商品に無料トライアルの導入オファーが付いている場合の日数
    let trialDays: Int?
    /// このユーザーが導入オファーの対象か（RevenueCat の checkTrialOrIntroDiscountEligibility が .eligible のときだけ true）
    let isTrialEligible: Bool

    /// トライアルを訴求するのは「商品にトライアルがあり、かつユーザーが適格」のときだけ
    var displayedTrialDays: Int? {
        guard isTrialEligible, let trialDays, trialDays > 0 else {
            return nil
        }
        return trialDays
    }
}

/// プランカードの表示内容。View はこの値を文言に変換するだけにして、表示分岐をユニットテストできるようにする。
struct SubscriptionPlanPresentation: Equatable {
    enum CallToAction: Equatable {
        /// 「無料で試す」
        case startFreeTrial
        /// 従来の「年額プランで購入する」/「月額プランで購入する」
        case purchase(SubscriptionPlanInfo.BillingPeriod)
    }

    /// 「7日間無料、その後 ¥300/月」と自動更新の注意書きに使う値
    struct TrialTerms: Equatable {
        let days: Int
        let priceAfterTrial: String
        let period: SubscriptionPlanInfo.BillingPeriod

        /// 「7日間無料、その後 ¥300/月」
        var headline: String {
            switch period {
            case .monthly:
                return String(localized: "\(days)日間無料、その後 \(priceAfterTrial)/月")
            case .annual:
                return String(localized: "\(days)日間無料、その後 \(priceAfterTrial)/年")
            }
        }

        /// ガイドライン3.1.2: 自動更新・課金額・キャンセル方法を明記する
        var renewalNotice: String {
            let renewal: String
            switch period {
            case .monthly:
                renewal = String(localized: "無料期間の終了後は自動的に \(priceAfterTrial)/月 で更新され、Apple ID に課金されます。")
            case .annual:
                renewal = String(localized: "無料期間の終了後は自動的に \(priceAfterTrial)/年 で更新され、Apple ID に課金されます。")
            }
            let cancel = String(localized: "いつでもキャンセル可能です。無料期間終了の24時間前までに「設定」アプリのサブスクリプションから解約すれば料金はかかりません。")
            return renewal + "\n" + cancel
        }
    }

    let callToAction: CallToAction
    let trialTerms: TrialTerms?

    init(plan: SubscriptionPlanInfo?, fallbackPeriod: SubscriptionPlanInfo.BillingPeriod) {
        if let plan, let days = plan.displayedTrialDays {
            callToAction = .startFreeTrial
            trialTerms = TrialTerms(days: days, priceAfterTrial: plan.price, period: plan.period)
        } else {
            callToAction = .purchase(plan?.period ?? fallbackPeriod)
            trialTerms = nil
        }
    }
}
