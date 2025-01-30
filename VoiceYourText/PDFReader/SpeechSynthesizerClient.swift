//
//  File.swift
//  VoiceYourText
//
//  Created by 遠藤拓弥 on 2025/01/17.
//

import Foundation
import AVFAudio
import Dependencies
import os

struct SpeechSynthesizerClient {
    var speak: (AVSpeechUtterance) async -> Void
    var stopSpeaking: () async -> Void
}

extension SpeechSynthesizerClient: DependencyKey {
    static let liveValue = Self(
        speak: { utterance in
            logger.info("Starting speech synthesis")
            await withCheckedContinuation { continuation in
                let synthesizer = AVSpeechSynthesizer()

                // 読み上げ完了を検知するデリゲートを設定
                let delegate = SpeechCompletionDelegate {
                    continuation.resume()
                }
                synthesizer.delegate = delegate

                synthesizer.speak(utterance)
                logger.debug("Speech utterance started")
            }
        },
        stopSpeaking: {
            logger.info("Stopping speech synthesis")
            await withCheckedContinuation { continuation in
                let synthesizer = AVSpeechSynthesizer()
                synthesizer.stopSpeaking(at: .immediate)
                logger.debug("Speech stopped")
                continuation.resume()
            }
        }
    )

    static var testValue: SpeechSynthesizerClient {
        Self(
            speak: { utterance in
                logger.info("Test: Starting speech synthesis simulation")
                logger.debug("Test: Speaking text: \(utterance.speechString)")
                // Simulate some async work
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                logger.debug("Test: Speech simulation completed")
            },
            stopSpeaking: {
                logger.info("Test: Stopping speech synthesis simulation")
                logger.debug("Test: Speech simulation stopped")
            }
        )
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.app.pdfreader",
        category: "SpeechSynthesizer"
    )
}

// 完了検知用のデリゲートクラス
private class SpeechCompletionDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        super.init()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onComplete()
    }
}

extension DependencyValues {
    var speechSynthesizer: SpeechSynthesizerClient {
        get { self[SpeechSynthesizerClient.self] }
        set { self[SpeechSynthesizerClient.self] = newValue }
    }
}
