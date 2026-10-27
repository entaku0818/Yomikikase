//
//  VoiceYourTextUITests.swift
//  VoiceYourTextUITests
//
//  Created by 遠藤拓弥 on 25.11.2023.
//

import XCTest

final class VoiceYourTextUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
    func testOnboardingJapaneseCanStopAndSkip() {
        verifyOnboarding(language: "ja", completeDemo: false)
    }

    func testOnboardingEnglishCanFinishDemo() {
        verifyOnboarding(language: "en", completeDemo: true)
    }

    func testOnboardingJapaneseCanFinishDemo() {
        verifyOnboarding(language: "ja", completeDemo: true)
    }

    func testOnboardingEnglishCanStopAndSkip() {
        verifyOnboarding(language: "en", completeDemo: false)
    }

    private func verifyOnboarding(language: String, completeDemo: Bool) {
        let app = XCUIApplication()
        let japanese = language == "ja"
        app.launchArguments = [
            "-HasCompletedOnboarding", "NO",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", japanese ? "ja_JP" : "en_US"
        ]
        app.launchEnvironment["SWIFT_DEPENDENCIES_CONTEXT"] = "live"
        app.launch()
        let start = app.buttons[japanese ? "はじめる" : "Get Started"]
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        for label in japanese ? ["勉強", "読書", "仕事の資料"] : ["Study", "Reading", "Work documents"] {
            XCTAssertTrue(app.staticTexts[label].exists, "Missing localized onboarding tag: \(label)")
        }
        start.tap()
        let play = app.buttons[japanese ? "約10秒のサンプルを聴く" : "Listen to a 10-second sample"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "onboarding-demo-\(language)"
        attachment.lifetime = .keepAlways
        add(attachment)
        play.tap()
        let stop = app.buttons[japanese ? "停止" : "Stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        if completeDemo {
            XCTAssertTrue(app.staticTexts[japanese ? "体験完了！次へ進めます" : "Demo complete! You can proceed."].waitForExistence(timeout: 40))
            app.buttons[japanese ? "次へ" : "Next"].tap()
        } else {
            stop.tap()
            XCTAssertTrue(play.waitForExistence(timeout: 5))
            app.buttons[japanese ? "スキップ" : "Skip"].tap()
        }
        let finish = app.buttons[japanese ? "使い始める" : "Start Using"]
        XCTAssertTrue(finish.waitForExistence(timeout: 10))
        let featureLabels = japanese
            ? ["PDF・書類", "PDFやスキャン書類を読み上げ", "ウェブページ", "URLを貼るだけで本文を読み上げ",
               "電子書籍", "EPUBファイルをそのまま読み上げ", "Googleドライブ", "クラウドのファイルに直接アクセス"]
            : ["PDFs & documents", "Listen to PDFs and scanned documents", "Web pages", "Paste a URL to listen to the article",
               "E-books", "Listen to EPUB books", "Google Drive", "Access your files in the cloud"]
        for label in featureLabels {
            XCTAssertTrue(app.staticTexts[label].exists, "Missing localized onboarding feature: \(label)")
        }
        finish.tap()
        XCTAssertTrue(finish.waitForNonExistence(timeout: 10))
    }

}
