//
//  SpeechSynthesizerClient.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 2025/01/17.
//

import Foundation
import AVFAudio
import Dependencies
import os
import ComposableArchitecture


@DependencyClient
struct SpeechSynthesizerClient {
    var speak: @Sendable (AVSpeechUtterance) async throws -> Bool
    var speakWithHighlight: @Sendable (AVSpeechUtterance, @escaping @Sendable (NSRange, String) -> Void, @escaping @Sendable () -> Void) async throws -> Bool
    var speakWithAPI: @Sendable (String, String?) async throws -> Bool
    var stopSpeaking: @Sendable () async -> Bool = { false }
    var pauseSpeaking: @Sendable () async -> Bool = { false }
    var continueSpeaking: @Sendable () async -> Bool = { false }
    var isPaused: @Sendable () async -> Bool = { false }
    /// 指定秒数でフェードアウトしてから停止する（スリープタイマー作動時）。
    /// 引数はフェードにかける秒数。
    var fadeOutAndStop: @Sendable (Double) async -> Bool = { _ in false }
}

extension SpeechSynthesizerClient: DependencyKey {
    static var liveValue: Self {
        let speechSynthesizer = SpeechSynthesizer()
        @Dependency(\.userDictionary) var userDictionary
        @Dependency(\.audioAPI) var audioAPI
        @Dependency(\.audioFileManager) var audioFileManager
        @Dependency(\.kokoroTTS) var kokoroTTS

        return Self(
            speak: { utterance in
                // Kokoro TTS パス（英語 or 日本語 / モデルDL済み / 有効）
                if UserDefaults.standard.bool(forKey: "KokoroEnabled"),
                   let lang = UserDefaults.standard.string(forKey: "LanguageSetting"),
                   (lang.hasPrefix("en") || lang.hasPrefix("ja")),
                   kokoroTTS.isAvailable() {
                    let isJapanese = lang.hasPrefix("ja")
                    let voiceName = UserDefaults.standard.string(forKey: "KokoroVoice") ?? ""
                    let candidate = KokoroVoice(rawValue: voiceName)
                    // 言語とボイスの方向が一致していなければデフォルトに落とす
                    let voice: KokoroVoice
                    if isJapanese {
                        voice = (candidate?.isJapanese == true) ? candidate! : .defaultJapanese
                    } else {
                        voice = (candidate?.isJapanese == false) ? candidate! : .default
                    }
                    do {
                        let data = try await kokoroTTS.synthesize(
                            utterance.speechString, voice, utterance.rate
                        )
                        return try await speechSynthesizer.playWAVData(data)
                    } catch {
                        // Kokoro失敗時はAVSpeechSynthesizerにフォールバック
                    }
                }

                // ユーザー辞書の読み方と日本語向けの読み前処理を適用
                let prepared = SpeechTextPreprocessor.prepare(
                    utterance.speechString,
                    languageCode: Self.languageCode(for: utterance),
                    readings: userDictionary.entries().map { (word: $0.word, reading: $0.reading) }
                )

                return try await speechSynthesizer.speak(
                    utterance: Self.rebuild(utterance, with: prepared.spoken)
                )
            },
            speakWithHighlight: { utterance, onHighlight, onFinish in
                // ユーザー辞書・前処理を適用したうえで読み上げ、ハイライト範囲は
                // PreparedSpeechText の対応表で「元のテキスト上の範囲」へ逆引きして返す。
                // これにより、辞書を適用してもハイライトがずれない。
                let originalText = utterance.speechString
                let plan = Self.highlightPlan(
                    for: utterance,
                    languageCode: Self.languageCode(for: utterance),
                    readings: userDictionary.entries().map { (word: $0.word, reading: $0.reading) }
                )

                return try await speechSynthesizer.speakWithHighlight(
                    utterance: plan.utterance,
                    onHighlight: { range, _ in
                        // 常に「元のテキスト」と、それに対する範囲を呼び出し側へ渡す
                        guard let mapped = plan.prepared.originalRange(forSpoken: range) else { return }
                        onHighlight(mapped, originalText)
                    },
                    onFinish: onFinish
                )
            },
            speakWithAPI: { text, voiceId in
                do {
                    // Generate audio via Cloud TTS API
                    let response = try await audioAPI.generateAudio(text, voiceId)

                    // Download and play the audio
                    guard let audioURL = URL(string: response.audioUrl) else {
                        errorLog("Invalid audio URL: \(response.audioUrl)")
                        return false
                    }

                    // Download audio file to local storage
                    let fileId = UUID().uuidString
                    let localURL = try await audioFileManager.downloadAudio(audioURL, fileId)

                    // Play the audio
                    return try await speechSynthesizer.playAudioFromURL(localURL.absoluteString)
                } catch {
                    errorLog("speakWithAPI failed: \(error)")
                    return false
                }
            },
            stopSpeaking: { await speechSynthesizer.stop() },
            pauseSpeaking: { await speechSynthesizer.pause() },
            continueSpeaking: { await speechSynthesizer.continueSpeaking() },
            isPaused: { await speechSynthesizer.isPaused() },
            fadeOutAndStop: { seconds in await speechSynthesizer.fadeOutAndStop(seconds: seconds) }
        )
    }
}

extension SpeechSynthesizerClient {

    /// 前処理に使う言語コードを決める。
    /// 解決済みの音声が持つ言語を最優先し、無ければユーザーの言語設定を使う。
    static func languageCode(for utterance: AVSpeechUtterance) -> String? {
        utterance.voice?.language ?? UserDefaultsManager.shared.languageSetting
    }

    /// speakWithHighlight が実際に読み上げる utterance と、ハイライト逆引き表を組み立てる。
    ///
    /// 副作用が無いので、ユーザー辞書がメイン再生経路で効いているかを
    /// そのままユニットテストできる（liveValue と同じ関数をテストが呼ぶ）。
    static func highlightPlan(
        for utterance: AVSpeechUtterance,
        languageCode: String?,
        readings: [(word: String, reading: String)]
    ) -> (utterance: AVSpeechUtterance, prepared: PreparedSpeechText) {
        let prepared = SpeechTextPreprocessor.prepare(
            utterance.speechString,
            languageCode: languageCode,
            readings: readings
        )
        // 変換が起きていなければ元の utterance をそのまま使う
        let spoken = prepared.isIdentity ? utterance : rebuild(utterance, with: prepared.spoken)
        return (spoken, prepared)
    }

    /// 読み上げ文字列だけを差し替えた utterance を作る。
    /// 音声・速度・ピッチ・音量・前後の無音はそのまま引き継ぐ。
    static func rebuild(_ utterance: AVSpeechUtterance, with text: String) -> AVSpeechUtterance {
        let rebuilt = AVSpeechUtterance(string: text)
        rebuilt.voice = utterance.voice
        rebuilt.rate = utterance.rate
        rebuilt.pitchMultiplier = utterance.pitchMultiplier
        rebuilt.volume = utterance.volume
        rebuilt.preUtteranceDelay = utterance.preUtteranceDelay
        rebuilt.postUtteranceDelay = utterance.postUtteranceDelay
        return rebuilt
    }
}

extension SpeechSynthesizerClient: TestDependencyKey {
    static let testValue = Self(
        speak: { _ in true },
        speakWithHighlight: { _, onHighlight, onFinish in
            // テスト用にハイライトコールバックを呼び出し
            onHighlight(NSRange(location: 0, length: 5), "テストテキスト")
            // 完了コールバックを呼び出し
            onFinish()
            return true
        },
        speakWithAPI: { _, _ in true },
        stopSpeaking: { true },
        pauseSpeaking: { true },
        continueSpeaking: { true },
        isPaused: { false },
        fadeOutAndStop: { _ in true }
    )
}

extension DependencyValues {
    var speechSynthesizer: SpeechSynthesizerClient {
        get { self[SpeechSynthesizerClient.self] }
        set { self[SpeechSynthesizerClient.self] = newValue }
    }
}

private actor SpeechSynthesizer {
    var delegate: Delegate?
    var synthesizer: AVSpeechSynthesizer?
    var activeContinuation: AsyncThrowingStream<Bool, Error>.Continuation?

    func stop() -> Bool {
        // Finish active continuation first to unblock any pending speak() task
        activeContinuation?.finish()
        activeContinuation = nil
        // Nil out delegate before stopping to prevent callbacks on deallocated objects
        synthesizer?.delegate = nil
        synthesizer?.stopSpeaking(at: .immediate)
        synthesizer = nil
        delegate = nil
        audioPlayer?.stop()
        audioPlayer = nil
        return true
    }

    func pause() -> Bool {
        guard let synthesizer = self.synthesizer else { return false }
        return synthesizer.pauseSpeaking(at: .word)
    }

    func continueSpeaking() -> Bool {
        guard let synthesizer = self.synthesizer else { return false }
        return synthesizer.continueSpeaking()
    }

    func isPaused() -> Bool {
        return self.synthesizer?.isPaused ?? false
    }

    /// フェードアウトしてから停止する。スリープタイマー作動時に音がぶつ切りにならないようにする。
    func fadeOutAndStop(seconds: Double) async -> Bool {
        let duration = max(0, seconds)

        if let player = audioPlayer, player.isPlaying {
            // AVAudioPlayer（Kokoro TTS / クラウドTTSの音声ファイル）は音量を落とせる。
            player.setVolume(0, fadeDuration: duration)
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            return stop()
        }

        if let synthesizer = self.synthesizer, synthesizer.isSpeaking {
            // AVSpeechSynthesizer は発話中の音量を変更できないため、音量フェードの代わりに
            // 単語の切れ目まで読ませてから止める（文の途中でぶつ切りにしない）。
            // delegate を先に外すのは、この停止で didCancel → onFinish が呼ばれ
            // 呼び出し側が「読み上げ完了」と誤認するのを防ぐため。
            synthesizer.delegate = nil
            synthesizer.stopSpeaking(at: .word)
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        return stop()
    }

    var audioPlayer: AVAudioPlayer?

    func playWAVData(_ data: Data) async throws -> Bool {
        stop()
        return await withCheckedContinuation { continuation in
            do {
                let player = try AVAudioPlayer(data: data)
                self.audioPlayer = player
                player.delegate = AudioPlayerDelegate { success in
                    continuation.resume(returning: success)
                }
                player.play()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    func playAudioFromURL(_ urlString: String) async throws -> Bool {
        guard let url = URL(string: urlString) else {
            throw AudioAPIError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        return await withCheckedContinuation { continuation in
            do {
                let audioPlayer = try AVAudioPlayer(data: data)
                self.audioPlayer = audioPlayer
                audioPlayer.delegate = AudioPlayerDelegate { success in
                    continuation.resume(returning: success)
                }
                audioPlayer.play()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    func speak(utterance: AVSpeechUtterance) async throws -> Bool {
        self.stop()
        let stream = AsyncThrowingStream<Bool, Error> { continuation in
            self.activeContinuation = continuation
            self.delegate = Delegate(
                didFinish: { flag in
                    continuation.yield(flag)
                    continuation.finish()
                },
                didError: { error in
                    if let error = error {
                        continuation.finish(throwing: error)
                    }
                },
                willSpeakRange: nil,
                onFinish: nil
            )
            let synthesizer = AVSpeechSynthesizer()
            self.synthesizer = synthesizer
            synthesizer.delegate = self.delegate

            continuation.onTermination = { [synthesizer = UncheckedSendable(synthesizer)] _ in
                synthesizer.wrappedValue.delegate = nil
                synthesizer.wrappedValue.stopSpeaking(at: .immediate)
            }

            synthesizer.speak(utterance)
        }

        for try await didFinish in stream {
            activeContinuation = nil
            return didFinish
        }
        activeContinuation = nil
        throw CancellationError()
    }

    func speakWithHighlight(utterance: AVSpeechUtterance, onHighlight: @escaping @Sendable (NSRange, String) -> Void, onFinish: @escaping @Sendable () -> Void) async throws -> Bool {
        self.stop()
        let stream = AsyncThrowingStream<Bool, Error> { continuation in
            self.activeContinuation = continuation
            self.delegate = Delegate(
                didFinish: { flag in
                    continuation.yield(flag)
                    continuation.finish()
                },
                didError: { error in
                    if let error = error {
                        continuation.finish(throwing: error)
                    }
                },
                willSpeakRange: onHighlight,
                onFinish: onFinish
            )
            let synthesizer = AVSpeechSynthesizer()
            self.synthesizer = synthesizer
            synthesizer.delegate = self.delegate

            continuation.onTermination = { [synthesizer = UncheckedSendable(synthesizer)] _ in
                synthesizer.wrappedValue.delegate = nil
                synthesizer.wrappedValue.stopSpeaking(at: .immediate)
            }

            synthesizer.speak(utterance)
        }

        for try await didFinish in stream {
            activeContinuation = nil
            return didFinish
        }
        activeContinuation = nil
        throw CancellationError()
    }
}

private final class Delegate: NSObject, AVSpeechSynthesizerDelegate {
    let didFinish: @Sendable (Bool) -> Void
    let didError: @Sendable (Error?) -> Void
    let willSpeakRange: (@Sendable (NSRange, String) -> Void)?
    let onFinish: (@Sendable () -> Void)?

    init(
        didFinish: @escaping @Sendable (Bool) -> Void,
        didError: @escaping @Sendable (Error?) -> Void,
        willSpeakRange: (@Sendable (NSRange, String) -> Void)? = nil,
        onFinish: (@Sendable () -> Void)? = nil
    ) {
        self.didFinish = didFinish
        self.didError = didError
        self.willSpeakRange = willSpeakRange
        self.onFinish = onFinish
        super.init()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        // デバッグ用ログ
        debugLog("willSpeakRange - location: \(characterRange.location), length: \(characterRange.length)")
        debugLog("Speech string: \(utterance.speechString)")
        if characterRange.location + characterRange.length <= utterance.speechString.count {
            let substring = (utterance.speechString as NSString).substring(with: characterRange)
            debugLog("Speaking: '\(substring)'")
        }
        
        willSpeakRange?(characterRange, utterance.speechString)
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        onFinish?()
        self.didFinish(true)
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        onFinish?()
        self.didFinish(false)
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didPause utterance: AVSpeechUtterance
    ) {
        self.didFinish(false)
    }
}

private class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let completion: @Sendable (Bool) -> Void
    
    init(completion: @escaping @Sendable (Bool) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completion(flag)
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        completion(false)
    }
}
