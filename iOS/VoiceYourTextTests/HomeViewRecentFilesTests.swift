//
//  HomeViewRecentFilesTests.swift
//  VoiceYourTextTests
//
//  ホームの「最近のファイル」が起動直後に出ない不具合（#156）の回帰テスト。
//  「最近のファイル」は Speeches.State.speechList を表示しており、その読み込みは .onAppear で行う。
//  HomeView を実際に描画して、表示時に .onAppear が送られることを確かめる。

import XCTest
import SwiftUI
import ComposableArchitecture
@testable import VoiceYourText

@MainActor
final class HomeViewRecentFilesTests: XCTestCase {

    func test_ホームを表示するとspeechListを読み込むonAppearが送られること() {
        var receivedOnAppear = false
        let store = Store<Speeches.State, Speeches.Action>(
            initialState: Speeches.State(currentText: "")
        ) {
            Reduce { _, action in
                if case .onAppear = action {
                    receivedOnAppear = true
                }
                return .none
            }
        }

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(
            // 非プレミアム時のバナー広告が AdConfig を要求するので、アプリ本体と同じく注入する
            rootView: HomeView(store: store) { _ in }
                .environmentObject(AdConfig.shared)
        )
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let deadline = Date().addingTimeInterval(5)
        while !receivedOnAppear && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }

        XCTAssertTrue(receivedOnAppear, "HomeView の表示時に Speeches.Action.onAppear が送られていない")
    }
}
