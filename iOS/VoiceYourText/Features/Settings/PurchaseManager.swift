import StoreKit
import RevenueCat
import FirebaseAnalytics
import os.log
protocol PurchaseManagerProtocol {
    func fetchProPlan() async throws -> (name: String, price: String)
    func fetchAllPlans() async throws -> (monthly: SubscriptionPlanInfo?, annual: SubscriptionPlanInfo?)
    func purchasePro() async throws -> PurchaseOutcome
    func purchasePro(planType: PurchaseManager.PlanType) async throws -> PurchaseOutcome
    /// 有効な購入が見つかれば true、購入履歴が無ければ false（エラーにはしない）
    func restorePurchases() async throws -> Bool
    func checkPremiumStatus() async
}

/// 購入処理の結果。ユーザーが購入シートを閉じたのは失敗ではないので、エラーと分けて返す。issue #157
enum PurchaseOutcome: Equatable {
    case purchased
    case cancelled

    /// 購入時に投げられたエラーが「ユーザーのキャンセル」かどうか。
    /// RevenueCat はキャンセルでも `ErrorCode.purchaseCancelledError` を投げる（userCancelled は true）。
    static func isCancellation(_ error: Error) -> Bool {
        if let code = error as? ErrorCode {
            return code == .purchaseCancelledError
        }
        let nsError = error as NSError
        if nsError.domain == ErrorCode.errorDomain {
            return nsError.code == ErrorCode.purchaseCancelledError.rawValue
        }
        if let skError = error as? SKError {
            return skError.code == .paymentCancelled
        }
        if let storeKitError = error as? StoreKitError, case .userCancelled = storeKitError {
            return true
        }
        return false
    }
}

class PurchaseManager: PurchaseManagerProtocol {
    private let logger = OSLog(subsystem: "com.entaku.VoiceYourText", category: "Purchase")
    static let shared = PurchaseManager()

    private enum Package {
        static let pro = "$rc_monthly"
        static let annual = "$rc_annual"
    }

    enum PlanType {
        case monthly
        case annual

        fileprivate var packageIdentifier: String {
            switch self {
            case .monthly: return Package.pro
            case .annual: return Package.annual
            }
        }
    }

    private init() {}

    enum PurchaseError: Error {
        case productNotFound
        case purchaseFailed
        case noEntitlements
    }

    func fetchProPlan() async throws -> (name: String, price: String) {
        os_log("=== Fetch Pro Plan Start ===", log: logger, type: .debug)
        let offerings = try await Purchases.shared.offerings()

        os_log("Current Offering ID: %{public}@", log: logger, type: .debug, offerings.current?.identifier ?? "nil")

        if let current = offerings.current {
            os_log("Packages in offering:", log: logger, type: .debug)
            current.availablePackages.forEach { package in
                os_log("- ID: %{public}@, Product: %{public}@", log: logger, type: .debug,
                       package.identifier, package.storeProduct.productIdentifier)
            }
        }

        guard let offering = offerings.current,
              let package = offering.availablePackages.first(where: { $0.identifier == Package.pro }) else {
            os_log("Pro package not found", log: logger, type: .error)
            throw PurchaseError.productNotFound
        }

        os_log("Found pro package: %{public}@", log: logger, type: .debug, package.identifier)
        os_log("=== Fetch Pro Plan End ===", log: logger, type: .debug)

        return (name: package.storeProduct.localizedTitle,
                price: package.localizedPriceString)
    }

    func fetchAllPlans() async throws -> (monthly: SubscriptionPlanInfo?, annual: SubscriptionPlanInfo?) {
        os_log("=== Fetch All Plans Start ===", log: logger, type: .debug)
        let offerings = try await Purchases.shared.offerings()

        guard let offering = offerings.current else {
            os_log("No current offering found", log: logger, type: .error)
            throw PurchaseError.productNotFound
        }

        let monthlyPackage = offering.availablePackages.first(where: { $0.identifier == Package.pro })
        let annualPackage = offering.availablePackages.first(where: { $0.identifier == Package.annual })

        // 導入オファー（無料トライアル）の適格判定。判定できない（.unknown 等）ときはトライアルを訴求しない
        let productIdentifiers = [monthlyPackage, annualPackage].compactMap { $0?.storeProduct.productIdentifier }
        let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: productIdentifiers)

        let monthly = monthlyPackage.map { planInfo(from: $0, period: .monthly, eligibility: eligibility) }
        let annual = annualPackage.map { planInfo(from: $0, period: .annual, eligibility: eligibility) }

        os_log("Fetched plans - monthly: %{public}@, annual: %{public}@",
               log: logger, type: .debug,
               monthly?.price ?? "nil", annual?.price ?? "nil")
        return (monthly: monthly, annual: annual)
    }

    private func planInfo(
        from package: RevenueCat.Package,
        period: SubscriptionPlanInfo.BillingPeriod,
        eligibility: [String: IntroEligibility]
    ) -> SubscriptionPlanInfo {
        let productIdentifier = package.storeProduct.productIdentifier
        let isEligible = eligibility[productIdentifier]?.status == .eligible
        os_log("Intro eligibility - %{public}@: %{public}@", log: logger, type: .debug,
               productIdentifier, isEligible ? "eligible" : "not eligible")
        return SubscriptionPlanInfo(
            name: package.storeProduct.localizedTitle,
            price: package.localizedPriceString,
            priceValue: package.storeProduct.price,
            period: period,
            trialDays: trialDays(from: package),
            isTrialEligible: isEligible
        )
    }

    private func trialDays(from package: RevenueCat.Package) -> Int? {
        guard let discount = package.storeProduct.introductoryDiscount,
              discount.paymentMode == .freeTrial else { return nil }
        let period = discount.subscriptionPeriod
        switch period.unit {
        case .day:   return period.value
        case .week:  return period.value * 7
        case .month: return period.value * 30
        default:     return nil
        }
    }

    func purchasePro() async throws -> PurchaseOutcome {
        return try await purchasePro(planType: .monthly)
    }

    func purchasePro(planType: PlanType) async throws -> PurchaseOutcome {
        os_log("=== Purchase Pro Start (planType: %{public}@) ===", log: logger, type: .debug,
               planType == .annual ? "annual" : "monthly")
        let offerings = try await Purchases.shared.offerings()

        guard let offering = offerings.current,
              let package = offering.availablePackages.first(where: { $0.identifier == planType.packageIdentifier }) else {
            os_log("Package not found for planType", log: logger, type: .error)
            throw PurchaseError.productNotFound
        }

        do {
            os_log("Starting purchase for package: %{public}@", log: logger, type: .debug, package.identifier)
            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)

            if userCancelled {
                os_log("Purchase cancelled by user", log: logger, type: .debug)
                return .cancelled
            }
            if customerInfo.entitlements["premium"]?.isActive == true {
                os_log("Purchase successful", log: logger, type: .debug)
                UserDefaultsManager.shared.isPremiumUser = true
                UserDefaultsManager.shared.premiumPurchaseDate = Date()
                Analytics.setUserProperty("true", forName: "is_premium")
                return .purchased
            } else {
                os_log("Purchase failed: premium not active", log: logger, type: .error)
                throw PurchaseError.purchaseFailed
            }
        } catch let error where PurchaseOutcome.isCancellation(error) {
            os_log("Purchase cancelled by user", log: logger, type: .debug)
            return .cancelled
        } catch {
            os_log("Purchase failed: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw error
        }
    }

    func restorePurchases() async throws -> Bool {
        os_log("=== Restore Purchases Start ===", log: logger, type: .debug)
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            if customerInfo.entitlements["premium"]?.isActive == true {
                os_log("Restore successful", log: logger, type: .debug)
                UserDefaultsManager.shared.isPremiumUser = true
                if UserDefaultsManager.shared.premiumPurchaseDate == nil {
                    UserDefaultsManager.shared.premiumPurchaseDate = Date()
                }
                Analytics.setUserProperty("true", forName: "is_premium")
                return true
            } else {
                // 購入履歴が無いのはエラーではない。端末のプレミアム状態もここでは消さない
                // （復元の空振りで購入日まで消していた。状態の同期は起動時の checkPremiumStatus に任せる）
                os_log("Restore finished: no entitlements found", log: logger, type: .debug)
                return false
            }
        } catch {
            os_log("Restore failed: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw error
        }
    }

    func checkPremiumStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let isPremium = customerInfo.entitlements["premium"]?.isActive == true
            
            Analytics.setUserProperty(isPremium ? "true" : "false", forName: "is_premium")
            if isPremium != UserDefaultsManager.shared.isPremiumUser {
                UserDefaultsManager.shared.isPremiumUser = isPremium
                if isPremium && UserDefaultsManager.shared.premiumPurchaseDate == nil {
                    UserDefaultsManager.shared.premiumPurchaseDate = Date()
                }
            }
        } catch {
            os_log("Failed to check premium status: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
}

extension SKProduct {
    var localizedPrice: String? {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = priceLocale
        return numberFormatter.string(from: price)
    }
}
