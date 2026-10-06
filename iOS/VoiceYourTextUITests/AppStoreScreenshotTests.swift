//
//  AppStoreScreenshotTests.swift
//  VoiceYourTextUITests
//
//  App Store 用スクリーンショットの素材（実画面）を撮る。
//  通常のテストでは何もしない。iOS/scripts/appstore_screenshots.sh から
//  SHOT_DIR / SHOT_LANG を渡したときだけ動く。
//

import XCTest

final class AppStoreScreenshotTests: XCTestCase {
    private var shotDir: URL!
    private var lang = "ja"
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["SHOT_DIR"], !dir.isEmpty else {
            throw XCTSkip("SHOT_DIR が無いので撮影しない（appstore_screenshots.sh 専用）")
        }
        continueAfterFailure = false
        shotDir = URL(fileURLWithPath: dir)
        lang = env["SHOT_LANG"] ?? "ja"
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)

        app = XCUIApplication()
        let locale = lang == "ja" ? "ja_JP" : "en_US"
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

    /// 撮る画面（素材名）。どれを何枚目に使うかは compose_screenshots.py が決める
    func testCaptureScreens() throws {
        let ja = lang == "ja"
        app.launch()
        sleep(3)

        // マイファイル（デモデータの一覧）
        app.buttons[ja ? "マイファイル" : "My Files"].tap()
        sleep(2)
        snap("myfiles")

        // 読み上げ中のハイライト。端末の声が単語を追い始めるまで待つ
        app.staticTexts[ja ? "吾輩は猫である" : "Alice's Adventures in Wonderland"].firstMatch.tap()
        sleep(2)
        app.buttons["play.fill"].firstMatch.tap()
        sleep(10)
        snap("playing")

        captureSpeedAndVoices(ja: ja)
        captureMiniPlayer(ja: ja)

        // ホーム（取り込める種類の一覧）
        app.buttons[ja ? "ホーム" : "Home"].tap()
        sleep(2)
        snap("home")

        captureSettings(ja: ja)
        app.buttons[ja ? "ホーム" : "Home"].tap()
        sleep(1)

        // 名作（青空文庫・日本語のみ）
        if ja {
            app.buttons["名作"].tap()
            sleep(4)
            snap("classics")
        }
        // 再生中のまま終えると、テスト後の診断収集が10分タイムアウトするまで xcodebuild が返らない
        app.terminate()
    }

    private func captureSpeedAndVoices(ja: Bool) {
        // 再生速度の選択
        app.buttons["1x"].firstMatch.tap()
        sleep(2)
        snap("speed")
        // iOS 27 では速度の選択がポップオーバーになり、キャンセルボタンが無い。外側をタップして閉じる
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.72)).tap()
        sleep(1)

        // 声を選ぶ前に止める（再生中だと停止ボタンの光がシート越しに写る。ミニプレイヤーの手前で再開する）
        if app.buttons["stop.fill"].firstMatch.exists {
            app.buttons["stop.fill"].firstMatch.tap()
            sleep(1)
        }
        // キャラ音声（VOICEVOX）は日本語のみなので、英語では撮らない
        if ja {
            app.buttons["声を選ぶ"].firstMatch.tap()
            sleep(2)
            // シートを全画面まで引き上げて一覧を多く見せる
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.49))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)))
            sleep(3)
            snap("voices")
            app.buttons["完了"].firstMatch.tap()
            sleep(2)
        }
    }

    private func captureMiniPlayer(ja: Bool) {
        // ミニプレイヤー＋スリープタイマー（再生中のまま画面を閉じる）
        if app.buttons["play.fill"].firstMatch.exists {
            app.buttons["play.fill"].firstMatch.tap()
            sleep(3)
        }
        app.buttons["chevron.down"].firstMatch.tap()
        sleep(2)
        // 画面を閉じると一時停止になるので、ミニプレイヤーから再開して「再生中」の見た目にする
        let resume = app.buttons["play.fill"].firstMatch
        if resume.exists {
            resume.tap()
            sleep(3)
        }
        // メニューを開いたままだと一覧に重なって見づらいので、30分を選んで残り時間が出た状態を撮る
        app.buttons[ja ? "スリープタイマー" : "Sleep timer"].firstMatch.tap()
        sleep(2)
        app.buttons[ja ? "30分後に停止" : "Stop in 30 min"].firstMatch.tap()
        sleep(3)
        snap("sleeptimer")
    }

    private func captureSettings(ja: Bool) {
        // ユーザー辞書（デモの単語が入っている）。6枚目に使う
        app.buttons[ja ? "設定" : "Settings"].tap()
        sleep(2)
        // 辞書の行がミニプレイヤーの下に隠れて、タップがミニプレイヤーに当たるのでスクロールしておく
        app.swipeUp()
        sleep(1)
        app.buttons[ja ? "ユーザー辞書" : "User Dictionary"].firstMatch.tap()
        sleep(5)
        snap("dictionary")
        // 戻るボタンは辞書画面の「＋」と取り違えやすいので、左端からのスワイプで戻る
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        sleep(1)
    }

    // MARK: - helpers

    private func snap(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: shotDir.appendingPathComponent("\(name).png"))
    }

    private func dump(_ name: String) {
        try? app.debugDescription.write(to: shotDir.appendingPathComponent("\(name).txt"), atomically: true, encoding: .utf8)
    }
}
