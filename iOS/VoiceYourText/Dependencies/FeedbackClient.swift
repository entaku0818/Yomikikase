import Foundation
import Dependencies
import UIKit
import FirebaseAppCheck

struct FeedbackClient {
    var submit: @Sendable (String) async throws -> Void
}

extension FeedbackClient: DependencyKey {
    static var liveValue: Self {
        Self { message in
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
            ])

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
        }
    }

    static var testValue: Self {
        Self { _ in }
    }
}

extension DependencyValues {
    var feedbackClient: FeedbackClient {
        get { self[FeedbackClient.self] }
        set { self[FeedbackClient.self] = newValue }
    }
}
