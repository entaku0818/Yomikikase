import Foundation
import Dependencies
import UIKit
import GoogleSignIn

// MARK: - Model

struct GoogleDriveFile: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let mimeType: String
    let modifiedTime: Date?
}

// MARK: - Client

struct GoogleDriveClient {
    var signIn: @Sendable () async throws -> Void
    var signOut: @Sendable () -> Void
    var currentUser: @Sendable () -> GIDGoogleUser?
    var listFiles: @Sendable () async throws -> [GoogleDriveFile]
    var fetchFileText: @Sendable (GoogleDriveFile) async throws -> String
}

extension GoogleDriveClient: DependencyKey {
    static let liveValue = Self(
        signIn: {
            let viewController = await MainActor.run {
                UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                    .first { $0.isKeyWindow }?
                    .rootViewController
            }
            guard let viewController else {
                throw GoogleDriveError.presentingViewControllerNotFound
            }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                GIDSignIn.sharedInstance.signIn(
                    withPresenting: viewController,
                    hint: nil,
                    additionalScopes: ["https://www.googleapis.com/auth/drive.readonly"]
                ) { _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        },
        signOut: {
            GIDSignIn.sharedInstance.signOut()
        },
        currentUser: {
            GIDSignIn.sharedInstance.currentUser
        },
        listFiles: {
            guard let user = GIDSignIn.sharedInstance.currentUser else {
                throw GoogleDriveError.notSignedIn
            }

            // Refresh token if expired
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                user.refreshTokensIfNeeded { _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }

            guard let token = GIDSignIn.sharedInstance.currentUser?.accessToken.tokenString else {
                throw GoogleDriveError.notSignedIn
            }

            let query = "mimeType='application/vnd.google-apps.document' or mimeType='text/plain' or mimeType='text/markdown'"
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlStr = "https://www.googleapis.com/drive/v3/files?q=\(encoded)&fields=files(id,name,mimeType,modifiedTime)&orderBy=modifiedTime+desc&pageSize=50"
            guard let url = URL(string: urlStr) else { throw GoogleDriveError.invalidResponse }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(DriveFilesResponse.self, from: data)
            let formatter = ISO8601DateFormatter()
            return response.files.map { file in
                GoogleDriveFile(
                    id: file.id,
                    name: file.name,
                    mimeType: file.mimeType,
                    modifiedTime: file.modifiedTime.flatMap { formatter.date(from: $0) }
                )
            }
        },
        fetchFileText: { file in
            guard let token = GIDSignIn.sharedInstance.currentUser?.accessToken.tokenString else {
                throw GoogleDriveError.notSignedIn
            }

            let urlStr: String
            if file.mimeType == "application/vnd.google-apps.document" {
                urlStr = "https://www.googleapis.com/drive/v3/files/\(file.id)/export?mimeType=text/plain"
            } else {
                urlStr = "https://www.googleapis.com/drive/v3/files/\(file.id)?alt=media"
            }
            guard let url = URL(string: urlStr) else { throw GoogleDriveError.invalidResponse }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let text = String(data: data, encoding: .utf8) else {
                throw GoogleDriveError.encodingError
            }
            return text
        }
    )

    static let testValue = Self(
        signIn: {},
        signOut: {},
        currentUser: { nil },
        listFiles: { [] },
        fetchFileText: { _ in "Test Google Drive content" }
    )
}

// MARK: - Dependency

extension DependencyValues {
    var googleDrive: GoogleDriveClient {
        get { self[GoogleDriveClient.self] }
        set { self[GoogleDriveClient.self] = newValue }
    }
}

// MARK: - Errors

enum GoogleDriveError: Error, LocalizedError {
    case notSignedIn
    case presentingViewControllerNotFound
    case invalidResponse
    case encodingError

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Googleアカウントにサインインしてください"
        case .presentingViewControllerNotFound:
            return "サインイン画面を表示できませんでした"
        case .invalidResponse:
            return "レスポンスの解析に失敗しました"
        case .encodingError:
            return "テキストのエンコーディングに失敗しました"
        }
    }
}

// MARK: - API Response Models

private struct DriveFilesResponse: Decodable {
    let files: [DriveFile]

    struct DriveFile: Decodable {
        let id: String
        let name: String
        let mimeType: String
        let modifiedTime: String?
    }
}
