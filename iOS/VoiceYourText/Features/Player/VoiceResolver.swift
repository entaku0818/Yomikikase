//
//  VoiceResolver.swift
//  VoiceYourText
//
//  再生時に使う AVSpeechSynthesisVoice の解決を一元化する。
//
//  従来は各再生パスが `AVSpeechSynthesisVoice(language:)` を直接呼んでいたため、
//  ユーザーが設定画面で選んだ音声（UserDefaults の "SelectedVoiceIdentifier"）が
//  実際の読み上げに反映されていなかった。Enhanced/Premium 音声をダウンロードして
//  選んでも従来のデフォルト品質の声で読まれてしまう、という穴を塞ぐためのヘルパー。
//

import Foundation
import AVFoundation

enum VoiceResolver {

    /// どの方法で音声を決めたかを表す。純粋ロジックをテストするための中間表現。
    enum Selection: Equatable {
        /// 保存済み identifier をそのまま使う
        case identifier(String)
        /// identifier が使えないので言語コードから既定音声を引く
        case language(String)
    }

    // MARK: - 純粋ロジック（テスト対象）

    /// 保存済み identifier を優先し、使えない場合は言語コードにフォールバックする。
    ///
    /// identifier が「使えない」ケース:
    ///   - 未保存
    ///   - 端末にその音声が存在しない（Enhanced/Premium を削除した、別端末から移行した等）
    ///   - 音声の言語が現在の読み上げ言語と一致しない
    ///     （例: 日本語の声を選んだまま言語設定を英語にした）
    ///
    /// - Parameters:
    ///   - savedIdentifier: UserDefaults に保存された音声 identifier
    ///   - languageCode: 読み上げ対象の言語コード（"ja" や "ja-JP" など）。nil なら fallback を使う
    ///   - fallbackLanguageCode: languageCode が nil のときに使う端末既定の言語コード。
    ///     `AVSpeechSynthesisVoice.currentLanguageCode()` は音声サービスへの問い合わせが
    ///     発生しうるため、実際に必要になるまで評価しない（@autoclosure）。
    ///   - voiceLanguage: identifier → その音声の言語コード。端末に無ければ nil を返すこと
    static func selection(
        savedIdentifier: String?,
        languageCode: String?,
        fallbackLanguageCode: @autoclosure () -> String,
        voiceLanguage: (String) -> String?
    ) -> Selection {
        let target = normalizedTarget(languageCode: languageCode, fallback: fallbackLanguageCode())

        if let identifier = savedIdentifier,
           !identifier.isEmpty,
           let voiceLang = voiceLanguage(identifier),
           languagesMatch(voiceLang, target) {
            return .identifier(identifier)
        }
        return .language(target)
    }

    /// 空文字やホワイトスペースだけの言語コードを弾いて実際に使う言語コードを決める。
    /// fallback は必要になったときだけ評価する（呼び出し側が重い処理を渡しても無駄打ちしない）。
    static func normalizedTarget(languageCode: String?, fallback: @autoclosure () -> String) -> String {
        guard let languageCode = languageCode?.trimmingCharacters(in: .whitespacesAndNewlines),
              !languageCode.isEmpty else {
            return fallback()
        }
        return languageCode
    }

    /// 言語コードの第一サブタグ（"ja-JP" → "ja"）が一致するか。
    /// 設定画面の絞り込み（`voice.language.starts(with: "ja")`）と同じ粒度で判定する。
    static func languagesMatch(_ lhs: String, _ rhs: String) -> Bool {
        primarySubtag(lhs) == primarySubtag(rhs)
    }

    /// "ja-JP" → "ja"、"en_US" → "en"。小文字に正規化する。
    static func primarySubtag(_ code: String) -> String {
        let separators = CharacterSet(charactersIn: "-_")
        let head = code.lowercased()
            .components(separatedBy: separators)
            .first ?? ""
        return head
    }

    // MARK: - AVFoundation との接続

    /// 実際に読み上げに使う音声を返す。
    ///
    /// - Parameters:
    ///   - savedIdentifier: 省略時は UserDefaults から読む
    ///   - languageCode: 省略時は UserDefaults の言語設定 → 端末既定 の順で決まる
    static func voice(
        savedIdentifier: String? = UserDefaultsManager.shared.selectedVoiceIdentifier,
        languageCode: String? = UserDefaultsManager.shared.languageSetting
    ) -> AVSpeechSynthesisVoice? {
        switch selection(
            savedIdentifier: savedIdentifier,
            languageCode: languageCode,
            fallbackLanguageCode: AVSpeechSynthesisVoice.currentLanguageCode(),
            voiceLanguage: { identifier in AVSpeechSynthesisVoice(identifier: identifier)?.language }
        ) {
        case .identifier(let identifier):
            // selection が identifier を返した時点で存在は確認済みだが、
            // 取得に失敗した場合に無音にならないよう language でも引き直す。
            return AVSpeechSynthesisVoice(identifier: identifier)
                ?? AVSpeechSynthesisVoice(language: languageCode)
        case .language(let code):
            return AVSpeechSynthesisVoice(language: code)
        }
    }

    /// `AVSpeechUtterance` に音声・速度・ピッチ・音量をまとめて適用する。
    /// 各再生パスで同じ設定を書き写さないための共通化。
    static func configure(
        _ utterance: AVSpeechUtterance,
        languageCode: String? = UserDefaultsManager.shared.languageSetting,
        rate: Float = UserDefaultsManager.shared.speechRate,
        pitch: Float = UserDefaultsManager.shared.speechPitch,
        volume: Float = defaultVolume
    ) {
        utterance.voice = voice(languageCode: languageCode)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.volume = volume
        utterance.postUtteranceDelay = SpeechSettings.interUtterancePause
    }

    /// 既存の各再生パスが使っていた固定音量。
    static let defaultVolume: Float = 0.75

    // MARK: - 音質（Enhanced / Premium）の判定

    /// 指定言語で Enhanced もしくは Premium 品質の音声が端末にあるか。
    /// 無ければ「設定アプリから高品質音声を落としてください」と誘導する。
    static func hasHighQualityVoice(languageCode: String) -> Bool {
        !highQualityVoices(languageCode: languageCode).isEmpty
    }

    /// 指定言語の Enhanced / Premium 音声一覧。
    static func highQualityVoices(languageCode: String) -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { languagesMatch($0.language, languageCode) }
            .filter { $0.quality == .enhanced || $0.quality == .premium }
    }

    /// 現在選択中の音声が既定品質のままで、かつ高品質音声も未ダウンロードか。
    /// = 高品質音声のダウンロード誘導を出すべき状態。
    static func shouldPromptHighQualityDownload(
        languageCode: String? = UserDefaultsManager.shared.languageSetting
    ) -> Bool {
        let target = normalizedTarget(
            languageCode: languageCode,
            fallback: AVSpeechSynthesisVoice.currentLanguageCode()
        )
        // すでに高品質音声を選んでいるなら誘導しない
        if let identifier = UserDefaultsManager.shared.selectedVoiceIdentifier,
           let selected = AVSpeechSynthesisVoice(identifier: identifier),
           selected.quality != .default {
            return false
        }
        return !hasHighQualityVoice(languageCode: target)
    }
}

// MARK: - 品質ラベル

extension AVSpeechSynthesisVoiceQuality {
    /// 設定画面・デバッグ画面で共通に使う表示名。
    var displayLabel: String? {
        switch self {
        case .enhanced: return String(localized: "高品質")
        case .premium:  return String(localized: "プレミアム")
        case .default:  return nil
        @unknown default: return nil
        }
    }
}
