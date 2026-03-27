import StoreKit
import RevenueCat
import os.log
protocol PurchaseManagerProtocol {
    func fetchProPlan() async throws -> (name: String, price: String)
    func fetchAllPlans() async throws -> (monthly: (name: String, price: String, trialDays: Int?)?, annual: (name: String, price: String, trialDays: Int?)?)
    func purchasePro() async throws -> Bool
    func purchasePro(planType: PurchaseManager.PlanType) async throws -> Bool
    func restorePurchases() async throws -> Bool
    func checkPremiumStatus() async
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

    func fetchAllPlans() async throws -> (monthly: (name: String, price: String, trialDays: Int?)?, annual: (name: String, price: String, trialDays: Int?)?) {
        os_log("=== Fetch All Plans Start ===", log: logger, type: .debug)
        let offerings = try await Purchases.shared.offerings()

        guard let offering = offerings.current else {
            os_log("No current offering found", log: logger, type: .error)
            throw PurchaseError.productNotFound
        }

        let monthlyPackage = offering.availablePackages.first(where: { $0.identifier == Package.pro })
        let annualPackage = offering.availablePackages.first(where: { $0.identifier == Package.annual })

        let monthly = monthlyPackage.map {
            (name: $0.storeProduct.localizedTitle,
             price: $0.localizedPriceString,
             trialDays: trialDays(from: $0))
        }
        let annual = annualPackage.map {
            (name: $0.storeProduct.localizedTitle,
             price: $0.localizedPriceString,
             trialDays: trialDays(from: $0))
        }

        os_log("Fetched plans - monthly: %{public}@, annual: %{public}@",
               log: logger, type: .debug,
               monthly?.price ?? "nil", annual?.price ?? "nil")
        return (monthly: monthly, annual: annual)
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

    func purchasePro() async throws -> Bool {
        return try await purchasePro(planType: .monthly)
    }

    func purchasePro(planType: PlanType) async throws -> Bool {
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
            let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)

            if customerInfo.entitlements["premium"]?.isActive == true {
                os_log("Purchase successful", log: logger, type: .debug)
                UserDefaultsManager.shared.isPremiumUser = true
                UserDefaultsManager.shared.premiumPurchaseDate = Date()
                return true
            } else {
                os_log("Purchase failed: premium not active", log: logger, type: .error)
                throw PurchaseError.purchaseFailed
            }
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
                return true
            } else {
                os_log("Restore failed: no entitlements found", log: logger, type: .error)
                UserDefaultsManager.shared.resetPremiumStatus()
                throw PurchaseError.noEntitlements
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
