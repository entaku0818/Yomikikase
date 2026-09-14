//
//  PersonalVoiceAccess.swift
//  VoiceYourText
//
//  パーソナルボイスを通常の再生経路で使えるようにするためのヘルパー。
//
//  パーソナルボイスは認可が下りている間しか `AVSpeechSynthesisVoice.speechVoices()`
//  に現れない。認可を取らないまま起動すると、設定で選んだパーソナルボイスの
//  identifier を VoiceResolver が解決できず、既定音声にフォールバックしてしまう。
//  そのため「パーソナルボイスを選んだことがあるユーザー」に限り、起動時に
//  認可を取り直して再生経路から使えるようにする。
//

import Foundation
import AVFoundation

enum PersonalVoiceAccess {

    /// 指定 identifier がパーソナルボイスか（認可済みのときのみ判定できる）。
    static func isPersonalVoice(identifier: String) -> Bool {
        guard let voice = AVSpeechSynthesisVoice(identifier: identifier) else { return false }
        return voice.voiceTraits.contains(.isPersonalVoice)
    }

    /// 端末で利用できるパーソナルボイス一覧（未認可なら空）。
    static func availableVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.voiceTraits.contains(.isPersonalVoice) }
    }

    /// 保存済み設定がパーソナルボイスを指している可能性があるときだけ認可を要求する。
    ///
    /// すでに `.authorized` なら何もしない。未認可でも、ユーザーが過去に
    /// パーソナルボイスを選んでいなければダイアログは出さない
    /// （初回起動でいきなり許可を求めない）。
    static func requestIfNeeded() {
        guard UserDefaultsManager.shared.usesPersonalVoice else { return }
        guard AVSpeechSynthesizer.personalVoiceAuthorizationStatus != .authorized else { return }
        AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
            infoLog("[PersonalVoice] authorization status: \(status.rawValue)")
        }
    }

    /// 認可を要求し、結果をコールバックで返す（設定画面から使う）。
    static func request(completion: @escaping (AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus) -> Void) {
        AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
            DispatchQueue.main.async { completion(status) }
        }
    }

    /// 選択された音声がパーソナルボイスなら、次回起動以降も認可を取り直せるよう記録する。
    static func rememberSelection(identifier: String?) {
        guard let identifier else { return }
        if isPersonalVoice(identifier: identifier) {
            UserDefaultsManager.shared.usesPersonalVoice = true
        }
    }
}
