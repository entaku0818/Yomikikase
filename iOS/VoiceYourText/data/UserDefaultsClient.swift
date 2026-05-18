import Foundation
import ComposableArchitecture

@DependencyClient
struct UserDefaultsClient: Sendable {
    // 言語・音声
    var languageSetting: @Sendable () -> String? = { nil }
    var setLanguageSetting: @Sendable (String?) -> Void
    var selectedVoiceIdentifier: @Sendable () -> String? = { nil }
    var setSelectedVoiceIdentifier: @Sendable (String?) -> Void
    var cloudTTSVoiceId: @Sendable () -> String? = { nil }
    var setCloudTTSVoiceId: @Sendable (String?) -> Void

    // 音声パラメータ
    var speechRate: @Sendable () -> Float = { 0.5 }
    var setSpeechRate: @Sendable (Float) -> Void
    var speechPitch: @Sendable () -> Float = { 1.0 }
    var setSpeechPitch: @Sendable (Float) -> Void

    // プレミアム
    var isPremiumUser: @Sendable () -> Bool = { false }
    var setIsPremiumUser: @Sendable (Bool) -> Void
    var premiumPurchaseDate: @Sendable () -> Date? = { nil }
    var setPremiumPurchaseDate: @Sendable (Date?) -> Void

    // Kokoro TTS
    var kokoroEnabled: @Sendable () -> Bool = { false }
    var setKokoroEnabled: @Sendable (Bool) -> Void
    var kokoroVoice: @Sendable () -> String? = { nil }
    var setKokoroVoice: @Sendable (String?) -> Void

    // オンボーディング
    var hasCompletedOnboarding: @Sendable () -> Bool = { false }
    var setHasCompletedOnboarding: @Sendable (Bool) -> Void

    // その他
    var speechCompletedCount: @Sendable () -> Int = { 0 }
    var setSpeechCompletedCount: @Sendable (Int) -> Void
    var appLaunchCount: @Sendable () -> Int = { 0 }
    var setAppLaunchCount: @Sendable (Int) -> Void
    var installDate: @Sendable () -> Date? = { nil }
    var setInstallDate: @Sendable (Date?) -> Void
    var reviewRequestCount: @Sendable () -> Int = { 0 }
    var setReviewRequestCount: @Sendable (Int) -> Void
    var lastReviewRequestDate: @Sendable () -> Date? = { nil }
    var setLastReviewRequestDate: @Sendable (Date?) -> Void
    var hasAnsweredReviewPositively: @Sendable () -> Bool = { false }
    var setHasAnsweredReviewPositively: @Sendable (Bool) -> Void

    // TTS ジョブ
    var pendingJobId: @Sendable (UUID) -> String? = { _ in nil }
    var setPendingJob: @Sendable (UUID, String) -> Void
    var clearPendingJob: @Sendable (UUID) -> Void
}

extension UserDefaultsClient: DependencyKey {
    static var liveValue: Self {
        let d = UserDefaults.standard
        return Self(
            languageSetting: { d.string(forKey: "LanguageSetting") },
            setLanguageSetting: { d.set($0, forKey: "LanguageSetting") },
            selectedVoiceIdentifier: { d.string(forKey: "SelectedVoiceIdentifier") },
            setSelectedVoiceIdentifier: { d.set($0, forKey: "SelectedVoiceIdentifier") },
            cloudTTSVoiceId: { d.string(forKey: "CloudTTSVoiceId") },
            setCloudTTSVoiceId: { d.set($0, forKey: "CloudTTSVoiceId") },
            speechRate: { let v = d.float(forKey: "SpeechRate"); return v == 0 ? 0.5 : v },
            setSpeechRate: { d.set($0, forKey: "SpeechRate") },
            speechPitch: { let v = d.float(forKey: "SpeechPitch"); return v == 0 ? 1.0 : v },
            setSpeechPitch: { d.set($0, forKey: "SpeechPitch") },
            isPremiumUser: { d.bool(forKey: "IsPremiumUser") },
            setIsPremiumUser: { newValue in
                d.set(newValue, forKey: "IsPremiumUser")
                d.synchronize()
                NotificationCenter.default.post(
                    name: Notification.Name("PremiumStatusDidChange"),
                    object: nil,
                    userInfo: ["isPremium": newValue]
                )
            },
            premiumPurchaseDate: { d.object(forKey: "PremiumPurchaseDate") as? Date },
            setPremiumPurchaseDate: { d.set($0, forKey: "PremiumPurchaseDate") },
            kokoroEnabled: { d.bool(forKey: "KokoroEnabled") },
            setKokoroEnabled: { d.set($0, forKey: "KokoroEnabled") },
            kokoroVoice: { d.string(forKey: "KokoroVoice") },
            setKokoroVoice: { d.set($0, forKey: "KokoroVoice") },
            hasCompletedOnboarding: { d.bool(forKey: "HasCompletedOnboarding") },
            setHasCompletedOnboarding: { d.set($0, forKey: "HasCompletedOnboarding") },
            speechCompletedCount: { d.object(forKey: "SpeechCompletedCount") as? Int ?? 0 },
            setSpeechCompletedCount: { d.set($0, forKey: "SpeechCompletedCount") },
            appLaunchCount: { d.integer(forKey: "AppLaunchCount") },
            setAppLaunchCount: { d.set($0, forKey: "AppLaunchCount") },
            installDate: { d.object(forKey: "InstallDate") as? Date },
            setInstallDate: { d.set($0, forKey: "InstallDate") },
            reviewRequestCount: { d.object(forKey: "ReviewRequestCount") as? Int ?? 0 },
            setReviewRequestCount: { d.set($0, forKey: "ReviewRequestCount") },
            lastReviewRequestDate: { d.object(forKey: "LastReviewRequestDate") as? Date },
            setLastReviewRequestDate: { d.set($0, forKey: "LastReviewRequestDate") },
            hasAnsweredReviewPositively: { d.bool(forKey: "HasAnsweredReviewPositively") },
            setHasAnsweredReviewPositively: { d.set($0, forKey: "HasAnsweredReviewPositively") },
            pendingJobId: { uuid in
                (d.dictionary(forKey: "PendingTTSJobs") as? [String: String])?[uuid.uuidString]
            },
            setPendingJob: { uuid, jobId in
                var jobs = (d.dictionary(forKey: "PendingTTSJobs") as? [String: String]) ?? [:]
                jobs[uuid.uuidString] = jobId
                d.set(jobs, forKey: "PendingTTSJobs")
            },
            clearPendingJob: { uuid in
                var jobs = (d.dictionary(forKey: "PendingTTSJobs") as? [String: String]) ?? [:]
                jobs.removeValue(forKey: uuid.uuidString)
                d.set(jobs, forKey: "PendingTTSJobs")
            }
        )
    }
}

extension DependencyValues {
    var userDefaults: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}
