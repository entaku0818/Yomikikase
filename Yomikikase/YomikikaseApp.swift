//
//  YomikikaseApp.swift
//  Yomikikase
//
//  Created by 遠藤拓弥 on 25.11.2023.
//

import ComposableArchitecture
import SwiftUI
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

}

@main
struct YomikikaseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            SpeechView(store: Store(initialState:
                                        Speeches.State(speechList: IdentifiedArrayOf(uniqueElements: []), currentText: "")) {
                Speeches()
            })
        }
    }
}
