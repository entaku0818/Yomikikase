//
//  HighQualityVoicePrompt.swift
//  VoiceYourText
//
//  Enhanced / Premium 音声のダウンロード誘導。
//
//  アプリから高品質音声を直接ダウンロードする公式APIは無く、ユーザーが
//  「設定 > アクセシビリティ > 読み上げコンテンツ > 声」から落とす必要がある。
//  設定画面だけでなく再生画面からも誘導できるよう、共通コンポーネントにしている。
//

import SwiftUI
import AVFoundation
import UIKit

/// 現在の読み上げ言語で使われている音声の状態。
enum VoiceQualityStatus: Equatable {
    /// Enhanced / Premium を選択して使っている
    case usingHighQuality(name: String, label: String)
    /// 高品質音声が端末にあるのに、既定品質の音声を使っている
    case highQualityAvailableButUnused
    /// 高品質音声が端末に無い（＝ダウンロード誘導を出す）
    case notDownloaded

    /// 現在の設定から状態を判定する。
    static func current(
        languageCode: String? = UserDefaultsManager.shared.languageSetting,
        selectedIdentifier: String? = UserDefaultsManager.shared.selectedVoiceIdentifier
    ) -> VoiceQualityStatus {
        let target = VoiceResolver.normalizedTarget(
            languageCode: languageCode,
            fallback: AVSpeechSynthesisVoice.currentLanguageCode()
        )

        if let identifier = selectedIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: identifier),
           VoiceResolver.languagesMatch(voice.language, target),
           let label = voice.quality.displayLabel {
            return .usingHighQuality(name: voice.name, label: label)
        }

        return VoiceResolver.hasHighQualityVoice(languageCode: target)
            ? .highQualityAvailableButUnused
            : .notDownloaded
    }
}

/// 高品質音声の状態表示と誘導カード。
struct HighQualityVoicePrompt: View {
    let status: VoiceQualityStatus
    /// 案内文を読み上げ言語に合わせるために使う（声の一覧で選ぶ言語名・代表的な音声名）。
    var languageCode: String? = UserDefaultsManager.shared.languageSetting
    /// 「音声を選ぶ」導線。設定画面内では nil（すでに一覧がその場にあるため）。
    var onSelectVoice: (() -> Void)?

    var body: some View {
        switch status {
        case .usingHighQuality(let name, let label):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(label)音声で読み上げ中")
                        .font(.subheadline)
                    Text(name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)

        case .highQualityAvailableButUnused:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                    Text("高品質音声が使えます")
                        .font(.headline)
                }
                Text("この端末には高品質音声がダウンロード済みです。音声を選ぶと、より自然な読み上げになります。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let onSelectVoice {
                    Button("音声を選ぶ", action: onSelectVoice)
                        .font(.callout)
                }
            }
            .padding(.vertical, 4)

        case .notDownloaded:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                    Text("\(HighQualityVoiceGuide.languageName(languageCode))の高品質音声を追加できます")
                        .font(.headline)
                }

                Text(HighQualityVoiceGuide.benefit)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // 4階層たどる必要があるので、1文にまとめず番号付きで出す。
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                            Text(step)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Button("「設定」アプリを開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.callout)

                Text(HighQualityVoiceGuide.openSettingsCaveat)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
    }

    private var steps: [String] {
        HighQualityVoiceGuide.steps(languageCode: languageCode)
    }
}

#Preview("未ダウンロード(日本語)") {
    Form { HighQualityVoicePrompt(status: .notDownloaded, languageCode: "ja") }
}

#Preview("未ダウンロード(英語)") {
    Form { HighQualityVoicePrompt(status: .notDownloaded, languageCode: "en") }
}

#Preview("未選択") {
    Form {
        HighQualityVoicePrompt(
            status: .highQualityAvailableButUnused,
            languageCode: "ja",
            onSelectVoice: {}
        )
    }
}

#Preview("使用中") {
    Form { HighQualityVoicePrompt(status: .usingHighQuality(name: "Kyoko", label: "高品質")) }
}
