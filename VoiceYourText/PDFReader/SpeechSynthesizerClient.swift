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
    var stopSpeaking: @Sendable () async -> Bool = { false }
}

extension SpeechSynthesizerClient: DependencyKey {
    static var liveValue: Self {
        let speechSynthesizer = SpeechSynthesizer()
        return Self(
            speak: { utterance in try await speechSynthesizer.speak(utterance: utterance) },
            stopSpeaking: { await speechSynthesizer.stop() }
        )
    }
}

extension SpeechSynthesizerClient: TestDependencyKey {
    static let testValue = Self(
        speak: { _ in true },
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
        return true
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
                    }
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

    init(
        didFinish: @escaping @Sendable (Bool) -> Void,
        didError: @escaping @Sendable (Error?) -> Void
    ) {
        self.didFinish = didFinish
        self.didError = didError
        super.init()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        self.didFinish(true)
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        self.didFinish(false)
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didPause utterance: AVSpeechUtterance
    ) {
        self.didFinish(false)
    }
}
