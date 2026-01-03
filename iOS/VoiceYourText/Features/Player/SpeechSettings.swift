//
//  SpeechSettings.swift
//  VoiceYourText
//
//  Created by Claude on 2025/01/03.
//

import Foundation
import AVFoundation

/// 音声再生設定の共通定数
enum SpeechSettings {
    /// 利用可能な再生速度オプション
    static let speedOptions: [Float] = [0.35, 0.5, 0.6, 0.75, 1.0]

    /// 再生速度を表示用文字列に変換（速度選択ダイアログ用）
    static func formatSpeedOption(_ rate: Float) -> String {
        let displayRate = rate / AVSpeechUtteranceDefaultSpeechRate
        if displayRate == 1.0 {
            return "1x"
        } else if displayRate == floor(displayRate) {
            return String(format: "%.0fx", displayRate)
        } else {
            return String(format: "%.1fx", displayRate)
        }
    }

    /// 再生速度を短い表示用文字列に変換（PlayerControlView用）
    static func formatSpeed(_ rate: Float) -> String {
        let displayRate = rate / AVSpeechUtteranceDefaultSpeechRate
        if displayRate == 1.0 {
            return "1x"
        } else if displayRate == floor(displayRate) {
            return String(format: "%.0fx", displayRate)
        } else {
            return String(format: "%.1fx", displayRate)
        }
    }
}
