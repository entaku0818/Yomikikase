//
//  AppStoreScreenshotTests.swift
//  VoiceYourTextUITests
//
//  App Store 用スクリーンショットの素材（実画面）を撮る。
//  通常のテストでは何もしない。iOS/scripts/appstore_screenshots.sh から
//  SHOT_DIR / SHOT_LANG / SHOT_LOCALE / SHOT_LABELS を渡したときだけ動く。
//  SHOT_LABELS は「日本語の文言 → その言語の文言」の JSON（スクリプトが Localizable.xcstrings から作る）。
//

import XCTest

final class AppStoreScreenshotTests: XCTestCase {
    private var shotDir: URL!
    private var lang = "ja"
    private var labels: [String: String] = [:]
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        let env = ProcessInfo.processInfo.environment
        if env["SHOT_MANIFEST"] != nil { return }
        guard let dir = env["SHOT_DIR"], !dir.isEmpty else {
            throw XCTSkip("SHOT_DIR が無いので撮影しない（appstore_screenshots.sh 専用）")
        }
        continueAfterFailure = false
        shotDir = URL(fileURLWithPath: dir)
        lang = env["SHOT_LANG"] ?? "ja"
        if let json = env["SHOT_LABELS"]?.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: json) {
            labels = decoded
        }
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)

        app = XCUIApplication()
        let locale = env["SHOT_LOCALE"] ?? "ja_JP"
        app.launchArguments = [
            "-ScreenshotSeed", lang,
            "-IsPremiumUser", "YES",
            "-HasCompletedOnboarding", "YES",
            "-AppleLanguages", "(\(lang))",
            "-AppleLocale", locale
        ]
        // UI テストから起動したアプリは TCA が「テスト中」と判定して testValue を使いうる。
        // 本番と同じ依存で撮るため live に固定する
        app.launchEnvironment["SWIFT_DEPENDENCIES_CONTEXT"] = "live"
    }

    override func tearDown() {
        app?.terminate()
        super.tearDown()
    }

    /// Capture the real app in every requested locale on either iPhone or iPad.
    func testCaptureAllLocales() throws {
        let env = ProcessInfo.processInfo.environment
        guard let manifestPath = env["SHOT_MANIFEST"], let output = env["SHOT_OUTPUT"] else {
            throw XCTSkip("Batch screenshot manifest not provided")
        }
        struct CaptureLocale: Decodable {
            let store: String
            let ui: String
            let home: String
            let myfiles: String
            let settings: String
            let sampleTitle: String
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
        let locales = try JSONDecoder().decode([CaptureLocale].self, from: data)
        continueAfterFailure = false
        for locale in locales {
            let application = XCUIApplication()
            application.launchArguments = [
                "-ScreenshotBatch", "YES", "-ScreenshotSeed", locale.ui,
                "-IsPremiumUser", "YES", "-HasCompletedOnboarding", "YES",
                "-AppleLanguages", "(\(locale.ui))", "-AppleLocale", locale.store.replacingOccurrences(of: "-", with: "_")
            ]
            application.launchEnvironment["SWIFT_DEPENDENCIES_CONTEXT"] = "live"
            application.launch()
            let directory = URL(fileURLWithPath: output).appendingPathComponent(locale.store)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (index, title) in [locale.home, locale.myfiles, locale.settings].enumerated() {
                let tab = application.buttons[title].firstMatch
                XCTAssertTrue(tab.waitForExistence(timeout: 20), "Missing tab: \(locale.store) / \(title)")
                tab.tap()
                if index == 1 {
                    XCTAssertTrue(application.staticTexts[locale.sampleTitle].firstMatch.waitForExistence(timeout: 10),
                                  "Localized sample missing for \(locale.store)")
                }
                if index == 2 {
                    XCTAssertTrue(application.sliders.firstMatch.waitForExistence(timeout: 30), "Settings did not appear for \(locale.store)")
                }
                settle(2) // Allow the tab transition to finish before capturing pixels.
                let filename = "\(index)_\(env["SHOT_DEVICE"] ?? "IPHONE").png"
                try XCUIScreen.main.screenshot().pngRepresentation.write(to: directory.appendingPathComponent(filename))
            }
            application.terminate()
            print("CAPTURED \(locale.store)")
        }
    }

    /// 撮る画面（素材名）。どれを何枚目に使うかは compose_screenshots.py が決める
    func testCaptureExpandedLocales() throws {
        let env = ProcessInfo.processInfo.environment
        guard let manifest = env["SHOT_MANIFEST"], let output = env["SHOT_OUTPUT"] else {
            throw XCTSkip("Expanded screenshot manifest not provided")
        }
        struct Locale: Decodable {
            let store: String
            let ui: String
            let labels: [String: String]
        }
        let locales = try JSONDecoder().decode([Locale].self, from: Data(contentsOf: URL(fileURLWithPath: manifest)))
        continueAfterFailure = false
        for locale in locales {
            shotDir = URL(fileURLWithPath: output).appendingPathComponent(locale.store)
            try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
            let names = ["playing", "home", "speed", "pdf", "sleeptimer", "dictionary"]
            if names.allSatisfy({ FileManager.default.fileExists(atPath: shotDir.appendingPathComponent($0 + ".png").path) }) {
                continue
            }
            lang = locale.ui
            labels = locale.labels
            app = XCUIApplication()
            app.launchArguments = [
                "-ScreenshotBatch", "YES", "-ScreenshotPlaybackFixture", "YES", "-ScreenshotSeed", locale.ui,
                "-HasCompletedOnboarding", "YES", "-AppleLanguages", "(\(locale.ui))",
                "-AppleLocale", locale.store.replacingOccurrences(of: "-", with: "_")
            ]
            app.launchEnvironment["SWIFT_DEPENDENCIES_CONTEXT"] = "live"
            try testCaptureScreens()
            print("CAPTURED_EXPANDED \(locale.store)")
        }
    }

    func testCaptureScreens() throws {
        let ja = lang == "ja"
        app.launch()
        settle(3)

        // マイファイル（デモデータの一覧）
        app.buttons[label("マイファイル")].firstMatch.tap()
        settle(2)
        snap("myfiles")

        // 読み上げ中のハイライト。端末の声が単語を追い始めるまで待つ
        app.staticTexts[label("_playTitle")].firstMatch.tap()
        settle(2)
        app.buttons["reader.play"].firstMatch.tap()
        // Mac が重いと再生開始が遅れる。停止ボタンが出る（=再生が始まる）のを待ってから、ハイライトが進むまで待つ
        XCTAssertTrue(app.buttons["reader.stop"].firstMatch.waitForExistence(timeout: 30),
                      "The reading state must be visible before capturing it")
        settle(8)
        snap("playing")

        captureSpeedAndVoices(ja: ja)
        captureMiniPlayer(ja: ja)

        // ホーム（取り込める種類の一覧）
        app.buttons[label("ホーム")].firstMatch.tap()
        settle(2)
        snap("home")

        captureSettings(ja: ja)
        capturePDF()
        app.buttons[label("ホーム")].firstMatch.tap()
        settle(1)

        // 名作（青空文庫・日本語のみ）
        if ja && !app.launchArguments.contains("-ScreenshotPlaybackFixture") {
            app.buttons[label("名作")].firstMatch.tap()
            settle(4)
            snap("classics")
        }
        // 再生中のまま終えると、テスト後の診断収集が10分タイムアウトするまで xcodebuild が返らない
        app.terminate()
    }

    private func captureSpeedAndVoices(ja: Bool) {
        // 再生速度の選択
        app.buttons["1x"].firstMatch.tap()
        settle(2)
        snap("speed")
        // iOS 27 では速度の選択がポップオーバーになり、キャンセルボタンが無い。外側をタップして閉じる
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.72)).tap()
        settle(1)

        // 声を選ぶ前に止める（再生中だと停止ボタンの光がシート越しに写る。ミニプレイヤーの手前で再開する）
        if app.buttons["reader.stop"].firstMatch.exists {
            app.buttons["reader.stop"].firstMatch.tap()
            settle(1)
        }
        // キャラ音声（VOICEVOX）は日本語のみなので、英語では撮らない
        if ja && !app.launchArguments.contains("-ScreenshotPlaybackFixture") {
            app.buttons["声を選ぶ"].firstMatch.tap()
            settle(2)
            // シートを全画面まで引き上げて一覧を多く見せる
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.49))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)))
            settle(3)
            XCTAssertTrue(app.staticTexts["ずんだもん"].firstMatch.waitForExistence(timeout: 20),
                          "Wait for the real voice catalog before capturing it")
            snap("voices")
            app.buttons["完了"].firstMatch.tap()
            settle(2)
        }
    }

    private func captureMiniPlayer(ja: Bool) {
        // ミニプレイヤー＋スリープタイマー（再生中のまま画面を閉じる）
        if app.buttons["reader.play"].firstMatch.exists {
            app.buttons["reader.play"].firstMatch.tap()
            settle(3)
        }
        app.buttons["chevron.down"].firstMatch.tap()
        settle(2)
        // 画面を閉じると一時停止になるので、ミニプレイヤーから再開して「再生中」の見た目にする
        let resume = app.buttons["mini.resume"].firstMatch
        if resume.exists {
            resume.tap()
            settle(3)
        }
        // メニューを開いたままだと一覧に重なって見づらいので、30分を選んで残り時間が出た状態を撮る
        app.buttons[label("スリープタイマー")].firstMatch.tap()
        settle(2)
        app.buttons[label("_sleep30")].firstMatch.tap()
        settle(3)
        snap("sleeptimer")
    }

    private func captureSettings(ja: Bool) {
        // ユーザー辞書（デモの単語が入っている）。6枚目に使う
        app.buttons[label("設定")].firstMatch.tap()
        settle(2)
        // 辞書の行がミニプレイヤーの下に隠れて、タップがミニプレイヤーに当たるのでスクロールしておく
        app.swipeUp()
        settle(1)
        app.buttons[label("ユーザー辞書")].firstMatch.tap()
        settle(5)
        snap("dictionary")
        // 戻るボタンは辞書画面の「＋」と取り違えやすいので、左端からのスワイプで戻る
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        settle(1)
    }

    private func capturePDF() {
        app.buttons[label("マイファイル")].firstMatch.tap()
        let sample = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH[c] '.pdf'")).firstMatch
        XCTAssertTrue(sample.waitForExistence(timeout: 10), "The seeded PDF must be visible")
        sample.tap()
        let play = app.buttons["reader.play"].firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 15), "The PDF reader must finish loading")
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: play)
        let ready = XCTWaiter.wait(for: [enabled], timeout: 20)
        if ready != .completed { snap("pdf-not-ready"); dump("pdf-not-ready") }
        XCTAssertEqual(ready, .completed, "Wait for extracted PDF text before starting playback")
        play.tap()
        let stop = app.buttons["reader.stop"].firstMatch
        let playing = stop.waitForExistence(timeout: 5)
        if !playing { snap("pdf-not-playing"); dump("pdf-not-playing") }
        XCTAssertTrue(playing, "Capture the PDF while it is reading")
        settle(2)
        snap("pdf")
        stop.tap()
        app.buttons["chevron.down"].firstMatch.tap()
    }

    private func settle(_ seconds: UInt32) {
        if app?.launchArguments.contains("-ScreenshotPlaybackFixture") == true {
            Thread.sleep(forTimeInterval: 0.25)
        } else {
            sleep(seconds)
        }
    }

    // MARK: - helpers

    /// その言語での文言。ラベルが無ければ日本語のまま
    private func label(_ key: String) -> String {
        labels[key] ?? key
    }

    private func snap(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: shotDir.appendingPathComponent("\(name).png"))
    }

    private func dump(_ name: String) {
        try? app.debugDescription.write(to: shotDir.appendingPathComponent("\(name).txt"), atomically: true, encoding: .utf8)
    }
}
