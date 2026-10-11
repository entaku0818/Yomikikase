import Foundation
import Dependencies
import UIKit
import FirebaseAppCheck

struct FeedbackClient {
    /// (本文, 返信先メール。空なら返信不要)
    var submit: @Sendable (String, String) async throws -> Void
}

/// 返信先メール（任意）の入力チェック。空は OK（返信不要）。サーバ側でも同じ基準で捨てる
enum FeedbackEmail {
    static func isAcceptable(_ value: String) -> Bool {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if email.isEmpty { return true }
        guard email.count <= 254 else { return false }
        return email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
}

extension FeedbackClient: DependencyKey {
    static var liveValue: Self {
        Self { message, email in
            let url = URL(string: "https://asia-northeast1-voiceyourtext.cloudfunctions.net/submitFeedback")!
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            let osVersion = await UIDevice.current.systemVersion
            let deviceModel = await UIDevice.current.model

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // App Checkトークンを付与する。取得に失敗しても送信自体は継続する
            // （サーバ側は監視モードのためトークン無しも受理する）。
            if let token = try? await AppCheck.appCheck().token(forcingRefresh: false) {
                request.setValue(token.token, forHTTPHeaderField: "X-Firebase-AppCheck")
            }

            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "message": message,
                "appVersion": appVersion,
                "osVersion": osVersion,
                "deviceModel": deviceModel,
                "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            ])

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
        }
    }

    static var testValue: Self {
        Self { _, _ in }
    }
}

extension DependencyValues {
    var feedbackClient: FeedbackClient {
        get { self[FeedbackClient.self] }
        set { self[FeedbackClient.self] = newValue }
    }
}
