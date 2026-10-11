import XCTest
@testable import VoiceYourText

/// フィードバックの返信先メール（任意）の入力チェック。サーバ（functions/index.js の normalizeEmail）と同じ基準
final class FeedbackEmailTests: XCTestCase {

    func test空欄は返信不要として送れる() {
        XCTAssertTrue(FeedbackEmail.isAcceptable(""))
        XCTAssertTrue(FeedbackEmail.isAcceptable("   "))
    }

    func test普通のメールアドレスは送れる_前後の空白は無視する() {
        XCTAssertTrue(FeedbackEmail.isAcceptable("user@example.com"))
        XCTAssertTrue(FeedbackEmail.isAcceptable(" user+tag@mail.example.co.jp "))
    }

    func test形式がおかしいものは送れない() {
        XCTAssertFalse(FeedbackEmail.isAcceptable("user"))
        XCTAssertFalse(FeedbackEmail.isAcceptable("user@example"))
        XCTAssertFalse(FeedbackEmail.isAcceptable("us er@example.com"))
        XCTAssertFalse(FeedbackEmail.isAcceptable(String(repeating: "a", count: 250) + "@example.com"))
    }
}
