//
//  VoiceYourTextApp.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 25.11.2023.
//

import ComposableArchitecture
import SwiftUI
import UIKit
import FirebaseCore

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()

        return true
    }

}

@main
struct VoiceYourTextApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let initialState = Speeches.State(
        speechList: IdentifiedArrayOf(uniqueElements: []),
        currentText: ""
    )

    var body: some Scene {
        WindowGroup {
            MainView(store:
                        Store(initialState: initialState, reducer: {
                Speeches()
            })
            )
        }
    }
}
