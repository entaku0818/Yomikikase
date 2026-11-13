import XCTest
import RevenueCat
@testable import VoiceYourText

final class PremiumVerificationTests: XCTestCase {
    func testOnlyVerifiedActiveEntitlementsGrantAccess() throws {
        for verification in [VerificationResult.verified, .verifiedOnDevice] {
            let suite = UUID().uuidString
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let storage = UserDefaultsManager(defaults: defaults)
            XCTAssertTrue(try PurchaseManager.applyPremiumStatus(
                isActive: true, verification: verification, storage: storage
            ))
            XCTAssertTrue(storage.isPremiumUser)
            XCTAssertFalse(try PurchaseManager.applyPremiumStatus(
                isActive: false, verification: verification, storage: storage
            ))
            XCTAssertFalse(storage.isPremiumUser)
        }
    }

    func testUntrustedResponsesRevokePreviouslyGrantedAccess() throws {
        for verification in [VerificationResult.failed, .notRequested] {
            let suite = UUID().uuidString
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let storage = UserDefaultsManager(defaults: defaults)
            _ = try PurchaseManager.applyPremiumStatus(isActive: true, verification: .verified, storage: storage)
            XCTAssertThrowsError(try PurchaseManager.applyPremiumStatus(
                isActive: true, verification: verification, storage: storage
            ))
            XCTAssertFalse(storage.isPremiumUser)
        }
    }

    func testLegacyFlagAndNewSessionCannotGrantAccess() throws {
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "IsPremiumUser")
        let storage = UserDefaultsManager(defaults: defaults)
        let client = UserDefaultsClient.live(store: defaults, premiumStorage: storage)
        XCTAssertFalse(storage.isPremiumUser)
        XCTAssertFalse(client.isPremiumUser())
        _ = try PurchaseManager.applyPremiumStatus(isActive: true, verification: .verified, storage: storage)
        XCTAssertTrue(client.isPremiumUser())
        XCTAssertFalse(UserDefaultsManager(defaults: defaults).isPremiumUser)
        XCTAssertNil(defaults.object(forKey: "IsPremiumUser"))
    }
}
