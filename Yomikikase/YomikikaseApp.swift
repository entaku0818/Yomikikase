//
//  YomikikaseApp.swift
//  Yomikikase
//
//  Created by 遠藤拓弥 on 25.11.2023.
//

import SwiftUI
import ComposableArchitecture


@main
struct YomikikaseApp: App {
    var body: some Scene {
        WindowGroup {
            SpeechView(store: Store(initialState:
                                        Speeches.State(speechList: IdentifiedArrayOf(uniqueElements: []), currentText: "")) {
                Speeches()
            })
        }
    }
}
