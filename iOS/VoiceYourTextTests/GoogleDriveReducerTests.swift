//
//  GoogleDriveReducerTests.swift
//  VoiceYourTextTests
//
//  QA: GoogleDriveFeature のエッジケーステスト
//  カバレッジ: ネットワークエラー / 空ファイル / 権限エラー / 状態遷移

import XCTest
import ComposableArchitecture
@testable import VoiceYourText

@MainActor
final class GoogleDriveReducerTests: XCTestCase {

    // MARK: - onAppear: 未サインイン

    func test_onAppear_notSignedIn_doesNotLoad() async {
        let store = TestStore(initialState: GoogleDriveFeature.State()) {
            GoogleDriveFeature()
        } withDependencies: {
            $0.googleDrive.currentUser = { nil }
        }

        // 未サインイン時: isSignedIn は初期値 false のまま、loadFiles() は呼ばれない
        await store.send(.view(.onAppear))
        // loadFiles() が呼ばれないことを確認（未完了エフェクトなし）
    }

    // MARK: - signInTapped: サインイン成功 → ファイル一覧取得

    func test_signInTapped_success_loadsFiles() async {
        let testFiles = [
            GoogleDriveFile(id: "1", name: "doc.txt", mimeType: "text/plain", modifiedTime: nil)
        ]

        let store = TestStore(initialState: GoogleDriveFeature.State()) {
            GoogleDriveFeature()
        } withDependencies: {
            $0.googleDrive.signIn = {}
            $0.googleDrive.listFiles = { testFiles }
        }

        await store.send(.view(.signInTapped)) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(.signedIn) {
            $0.isSignedIn = true
        }
        await store.receive(.filesLoaded(testFiles)) {
            $0.isLoading = false
            $0.files = testFiles
        }
    }

    // MARK: - signInTapped: ネットワークエラー（権限拒否含む）

    func test_signInTapped_networkError_setsErrorMessage() async {
        let store = TestStore(initialState: GoogleDriveFeature.State()) {
            GoogleDriveFeature()
        } withDependencies: {
            $0.googleDrive.signIn = { throw GoogleDriveError.presentingViewControllerNotFound }
        }

        let expectedMessage = GoogleDriveError.presentingViewControllerNotFound.localizedDescription

        await store.send(.view(.signInTapped)) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(.errorOccurred(expectedMessage)) {
            $0.isLoading = false
            $0.errorMessage = expectedMessage
        }
    }

    func test_signInTapped_notSignedInError_setsErrorMessage() async {
        let store = TestStore(initialState: GoogleDriveFeature.State()) {
            GoogleDriveFeature()
        } withDependencies: {
            $0.googleDrive.signIn = { throw GoogleDriveError.notSignedIn }
        }

        let expectedMessage = GoogleDriveError.notSignedIn.localizedDescription

        await store.send(.view(.signInTapped)) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(.errorOccurred(expectedMessage)) {
            $0.isLoading = false
            $0.errorMessage = expectedMessage
        }
    }

    // MARK: - signInTapped: サインイン成功後のファイル一覧取得失敗

    func test_signInTapped_listFilesFails_setsErrorMessage() async {
        let store = TestStore(initialState: GoogleDriveFeature.State()) {
            GoogleDriveFeature()
        } withDependencies: {
            $0.googleDrive.signIn = {}
            $0.googleDrive.listFiles = { throw GoogleDriveError.notSignedIn }
        }

        let expectedMessage = GoogleDriveError.notSignedIn.localizedDescription

        await store.send(.view(.signInTapped)) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(.signedIn) {
            $0.isSignedIn = true
        }
        await store.receive(.errorOccurred(expectedMessage)) {
            $0.isLoading = false
            $0.errorMessage = expectedMessage
        }
    }

    // MARK: - signOutTapped

    func test_signOutTapped_clearsFilesAndSignedInState() async {
        let files = [GoogleDriveFile(id: "1", name: "doc.txt", mimeType: "text/plain", modifiedTime: nil)]
        let store = TestStore(
            initialState: GoogleDriveFeature.State(isSignedIn: true, files: files)
        ) {
            GoogleDriveFeature()
        } withDependencies: {
            $0.googleDrive.signOut = {}
        }

        await store.send(.view(.signOutTapped))
        await store.receive(.signedOut) {
            $0.isSignedIn = false
            $0.files = []
        }
    }

    // MARK: - fileTapped: テキスト取得成功

    func test_fileTapped_success_setsExtractedText() async {
        let file = GoogleDriveFile(id: "1", name: "report.txt", mimeType: "text/plain", modifiedTime: nil)
        let expectedText = "Hello World\n本文テキスト"

        let store = TestStore(
            initialState: GoogleDriveFeature.State(isSignedIn: true, files: [file])
        ) {
            GoogleDriveFeature()
        } withDependencies: {
            $0.googleDrive.fetchFileText = { _ in expectedText }
        }

        await store.send(.view(.fileTapped(file))) {
            $0.isLoadingFile = true
            $0.errorMessage = nil
        }
        await store.receive(.fileTextLoaded(expectedText)) {
            $0.isLoadingFile = false
            $0.extractedText = expectedText
            $0.didExtractText = true
        }
    }

    // MARK: - fileTapped: 空ファイル（QAバグ修正済み）

    /// fix: 空テキスト取得時はエラーメッセージを表示し didExtractText は false のまま
    func test_fileTapped_emptyContent_showsError() async {
        let file = GoogleDriveFile(id: "2", name: "empty.txt", mimeType: "text/plain", modifiedTime: nil)

        let store = TestStore(
            initialState: GoogleDriveFeature.State(isSignedIn: true, files: [file])
        ) {
            GoogleDriveFeature()
        } withDependencies: {
            $0.googleDrive.fetchFileText = { _ in "" }
        }

        await store.send(.view(.fileTapped(file))) {
            $0.isLoadingFile = true
            $0.errorMessage = nil
        }
        await store.receive(.fileTextLoaded("")) {
            $0.isLoadingFile = false
            $0.errorMessage = "ファイルのテキストが空です"
            // didExtractText は false のまま（空読み上げを防ぐ）
        }
    }

    func test_fileTapped_whitespaceOnlyContent_showsError() async {
        let file = GoogleDriveFile(id: "3", name: "spaces.txt", mimeType: "text/plain", modifiedTime: nil)

        let store = TestStore(
            initialState: GoogleDriveFeature.State(isSignedIn: true, files: [file])
        ) {
            GoogleDriveFeature()
        } withDependencies: {
            $0.googleDrive.fetchFileText = { _ in "   \n\t  " }
        }

        await store.send(.view(.fileTapped(file))) {
            $0.isLoadingFile = true
        }
        await store.receive(.fileTextLoaded("   \n\t  ")) {
            $0.isLoadingFile = false
            $0.errorMessage = "ファイルのテキストが空です"
        }
    }

    // MARK: - fileTapped: ネットワークエラー

    func test_fileTapped_networkError_setsErrorMessage() async {
        let file = GoogleDriveFile(id: "1", name: "doc.txt", mimeType: "text/plain", modifiedTime: nil)
        let expectedMessage = GoogleDriveError.invalidResponse.localizedDescription

        let store = TestStore(
            initialState: GoogleDriveFeature.State(isSignedIn: true, files: [file])
        ) {
            GoogleDriveFeature()
        } withDependencies: {
            $0.googleDrive.fetchFileText = { _ in throw GoogleDriveError.invalidResponse }
        }

        await store.send(.view(.fileTapped(file))) {
            $0.isLoadingFile = true
            $0.errorMessage = nil
        }
        await store.receive(.errorOccurred(expectedMessage)) {
            $0.isLoadingFile = false
            $0.errorMessage = expectedMessage
        }
    }

    func test_fileTapped_encodingError_setsErrorMessage() async {
        let file = GoogleDriveFile(id: "1", name: "binary.txt", mimeType: "text/plain", modifiedTime: nil)
        let expectedMessage = GoogleDriveError.encodingError.localizedDescription

        let store = TestStore(
            initialState: GoogleDriveFeature.State(isSignedIn: true, files: [file])
        ) {
            GoogleDriveFeature()
        } withDependencies: {
            $0.googleDrive.fetchFileText = { _ in throw GoogleDriveError.encodingError }
        }

        await store.send(.view(.fileTapped(file))) {
            $0.isLoadingFile = true
            $0.errorMessage = nil
        }
        await store.receive(.errorOccurred(expectedMessage)) {
            $0.isLoadingFile = false
            $0.errorMessage = expectedMessage
        }
    }

    // MARK: - filesLoaded: 空リスト

    func test_filesLoaded_empty_stopsLoading() async {
        let store = TestStore(
            initialState: GoogleDriveFeature.State(isSignedIn: true, isLoading: true)
        ) {
            GoogleDriveFeature()
        }

        await store.send(.filesLoaded([])) {
            $0.isLoading = false
            $0.files = []
        }
    }

    // MARK: - errorOccurred: ローディング状態のリセット

    func test_errorOccurred_resetsLoadingFlags() async {
        let store = TestStore(
            initialState: GoogleDriveFeature.State(isSignedIn: true, isLoading: true, isLoadingFile: true)
        ) {
            GoogleDriveFeature()
        }

        await store.send(.errorOccurred("接続タイムアウト")) {
            $0.isLoading = false
            $0.isLoadingFile = false
            $0.errorMessage = "接続タイムアウト"
        }
    }

    // MARK: - GoogleDriveError: エラーメッセージが空でない

    func test_allGoogleDriveErrors_haveLocalizedDescriptions() {
        let errors: [GoogleDriveError] = [
            .notSignedIn,
            .presentingViewControllerNotFound,
            .invalidResponse,
            .encodingError
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) の errorDescription が nil")
            XCTAssertFalse(error.errorDescription!.isEmpty, "\(error) の errorDescription が空")
        }
    }
}
