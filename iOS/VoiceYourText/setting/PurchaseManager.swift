import StoreKit
import RevenueCat
import os.log
protocol PurchaseManagerProtocol {
    func fetchProPlan() async throws -> (name: String, price: String)
    func purchasePro() async throws -> Bool
    func restorePurchases() async throws -> Bool
    func checkPremiumStatus() async
}

class PurchaseManager: PurchaseManagerProtocol {
    private let logger = OSLog(subsystem: "com.entaku.VoiceYourText", category: "Purchase")
    static let shared = PurchaseManager()

    private enum Package {
        static let pro = "$rc_monthly"
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

    func purchasePro() async throws -> Bool {
        os_log("=== Purchase Pro Start ===", log: logger, type: .debug)
        let offerings = try await Purchases.shared.offerings()

        guard let offering = offerings.current,
              let package = offering.availablePackages.first(where: { $0.identifier == Package.pro }) else {
            os_log("Pro package not found", log: logger, type: .error)
            throw PurchaseError.productNotFound
        }

        do {
            os_log("Starting pro purchase for package: %{public}@", log: logger, type: .debug, package.identifier)
            let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)

            if customerInfo.entitlements["premium"]?.isActive == true {
                os_log("Pro purchase successful", log: logger, type: .debug)
                UserDefaultsManager.shared.isPremiumUser = true
                UserDefaultsManager.shared.premiumPurchaseDate = Date()
                return true
            } else {
                os_log("Pro purchase failed: premium not active", log: logger, type: .error)
                throw PurchaseError.purchaseFailed
            }
        } catch {
            os_log("Pro purchase failed: %{public}@", log: logger, type: .error, error.localizedDescription)
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
