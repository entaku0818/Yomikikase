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
}

extension SpeechSynthesizerClient: DependencyKey {
    static var liveValue: Self {
        let speechSynthesizer = SpeechSynthesizer()
        @Dependency(\.userDictionary) var userDictionary
        // TODO: Re-enable when Audio API is ready
        // @Dependency(\.audioAPI) var audioAPI

        return Self(
            speak: { utterance in
                // ユーザー辞書の読み方を適用
                let text = utterance.speechString
                let words = text.components(separatedBy: .whitespacesAndNewlines)
                var modifiedText = text
                
                for word in words {
                    if let reading = userDictionary.getReading(word) {
                        modifiedText = modifiedText.replacingOccurrences(of: word, with: reading)
                    }
                }
                
                // 新しいAVSpeechUtteranceを作成
                let modifiedUtterance = AVSpeechUtterance(string: modifiedText)
                modifiedUtterance.rate = utterance.rate
                modifiedUtterance.pitchMultiplier = utterance.pitchMultiplier
                modifiedUtterance.volume = utterance.volume
                modifiedUtterance.voice = utterance.voice
                
                return try await speechSynthesizer.speak(utterance: modifiedUtterance)
            },
            speakWithHighlight: { utterance, onHighlight, onFinish in
                // ハイライト機能では元のテキストを保持する必要があるため、
                // ユーザー辞書の適用は行わずに元のテキストで音声合成を実行
                return try await speechSynthesizer.speakWithHighlight(
                    utterance: utterance, 
                    onHighlight: { range, _ in
                        // 元のテキストに対する範囲を送信
                        onHighlight(range, utterance.speechString)
                    }, 
                    onFinish: onFinish
                )
            },
            speakWithAPI: { text, voiceId in
                // TODO: Re-enable when Audio API is ready
                print("Audio API is currently disabled")
                return false
            },
            stopSpeaking: { await speechSynthesizer.stop() }
        )
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
        stopSpeaking: { true }
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

    func stop() -> Bool {
        self.synthesizer?.stopSpeaking(at: .immediate)
        self.audioPlayer?.stop()
        return true
    }
    
    var audioPlayer: AVAudioPlayer?
    
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
            do {
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
                    synthesizer.wrappedValue.stopSpeaking(at: .immediate)
                }

                synthesizer.speak(utterance)
            } catch {
                continuation.finish(throwing: error)
            }
        }

        for try await didFinish in stream {
            return didFinish
        }
        throw CancellationError()
    }

    func speakWithHighlight(utterance: AVSpeechUtterance, onHighlight: @escaping @Sendable (NSRange, String) -> Void, onFinish: @escaping @Sendable () -> Void) async throws -> Bool {
        self.stop()
        let stream = AsyncThrowingStream<Bool, Error> { continuation in
            do {
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
                    synthesizer.wrappedValue.stopSpeaking(at: .immediate)
                }

                synthesizer.speak(utterance)
            } catch {
                continuation.finish(throwing: error)
            }
        }

        for try await didFinish in stream {
            return didFinish
        }
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
        print("🎯 willSpeakRange - location: \(characterRange.location), length: \(characterRange.length)")
        print("📝 Speech string: \(utterance.speechString)")
        if characterRange.location + characterRange.length <= utterance.speechString.count {
            let substring = (utterance.speechString as NSString).substring(with: characterRange)
            print("🔤 Speaking: '\(substring)'")
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
