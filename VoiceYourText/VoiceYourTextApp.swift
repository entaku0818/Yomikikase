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
        let languageCode:String = UserDefaultsManager.shared.languageSetting ?? "en"
        UserDefaults.standard.set([languageCode], forKey: "AppleLocale")
        UserDefaults.standard.synchronize()
        return true
    }

}

@main
struct VoiceYourTextApp: App {
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
