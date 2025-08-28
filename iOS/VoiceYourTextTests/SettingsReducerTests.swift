//
//  a.swift
//  VoiceYourTextTests
//
//  Created by 遠藤拓弥 on 2024/11/05.
//

import XCTest
import ComposableArchitecture
import AVFoundation
@testable import VoiceYourText

final class SettingsReducerTests: XCTestCase {

    @MainActor
    func test_デフォルト設定時のRate設定が合っているか確認() async {
        let store = TestStore(initialState: SettingsReducer.State(speechRate: 2.0)) {
            SettingsReducer()
        }

        // resetToDefaultアクションを送信
        await store.send(.resetToDefault) { state in
            state.speechRate = 0.5
        }
    }
}
