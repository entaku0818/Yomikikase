//
//  VoiceDumpView.swift
//  VoiceYourText
//
//  端末に入っている AVSpeechSynthesisVoice を全件ダンプするデバッグ画面。
//
//  「ja-JP に .enhanced / .premium が実在するか」を実機で確認するために用意した。
//  シミュレータと実機で入っている音声が違うため、実機で開いて確認すること。
//

#if DEBUG

import SwiftUI
import AVFoundation
import UIKit

struct VoiceDumpView: View {
    @State private var searchText: String = ""
    @State private var onlyHighQuality: Bool = false
    @State private var copied: Bool = false

    private var allVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .sorted { lhs, rhs in
                if lhs.language != rhs.language { return lhs.language < rhs.language }
                if lhs.quality.rawValue != rhs.quality.rawValue {
                    return lhs.quality.rawValue > rhs.quality.rawValue
                }
                return lhs.name < rhs.name
            }
    }

    private var filteredVoices: [AVSpeechSynthesisVoice] {
        allVoices
            .filter { onlyHighQuality ? $0.quality != .default : true }
            .filter { voice in
                guard !searchText.isEmpty else { return true }
                let needle = searchText.lowercased()
                return voice.language.lowercased().contains(needle)
                    || voice.name.lowercased().contains(needle)
                    || voice.identifier.lowercased().contains(needle)
            }
    }

    /// 言語ごとの件数と、Enhanced/Premium を持っているか。
    private var languageSummary: [(language: String, total: Int, high: Int)] {
        Dictionary(grouping: allVoices, by: \.language)
            .map { language, voices in
                (language, voices.count, voices.filter { $0.quality != .default }.count)
            }
            .sorted { $0.language < $1.language }
    }

    var body: some View {
        List {
            Section("サマリー") {
                LabeledContent("音声の総数", value: "\(allVoices.count)")
                LabeledContent(
                    "Enhanced",
                    value: "\(allVoices.filter { $0.quality == .enhanced }.count)"
                )
                LabeledContent(
                    "Premium",
                    value: "\(allVoices.filter { $0.quality == .premium }.count)"
                )
                LabeledContent(
                    "パーソナルボイス",
                    value: "\(PersonalVoiceAccess.availableVoices().count)"
                )
                LabeledContent(
                    "パーソナルボイス認可",
                    value: Self.authLabel(AVSpeechSynthesizer.personalVoiceAuthorizationStatus)
                )
            }

            Section("現在の解決結果") {
                LabeledContent("言語設定", value: UserDefaultsManager.shared.languageSetting ?? "(未設定)")
                LabeledContent(
                    "保存済み identifier",
                    value: UserDefaultsManager.shared.selectedVoiceIdentifier ?? "(未設定)"
                )
                let resolved = VoiceResolver.voice()
                LabeledContent("実際に使われる音声", value: resolved?.name ?? "(なし)")
                LabeledContent("その言語", value: resolved?.language ?? "-")
                LabeledContent("その品質", value: resolved.map { Self.qualityLabel($0.quality) } ?? "-")
            }

            Section("言語別") {
                ForEach(languageSummary, id: \.language) { row in
                    HStack {
                        Text(row.language)
                        Spacer()
                        Text("\(row.total)件")
                            .foregroundColor(.secondary)
                        if row.high > 0 {
                            Text("高品質\(row.high)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                    .font(.system(.footnote, design: .monospaced))
                }
            }

            Section("音声一覧（\(filteredVoices.count)件）") {
                Toggle("高品質のみ表示", isOn: $onlyHighQuality)
                ForEach(filteredVoices, id: \.identifier) { voice in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(voice.name).font(.callout)
                            if let label = voice.quality.displayLabel {
                                Text(label)
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(
                                        (voice.quality == .premium ? Color.purple : Color.blue)
                                            .opacity(0.15)
                                    )
                                    .foregroundColor(voice.quality == .premium ? .purple : .blue)
                                    .cornerRadius(4)
                            }
                            if voice.voiceTraits.contains(.isPersonalVoice) {
                                Text("パーソナル")
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            }
                            Spacer()
                            Text(voice.language)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(voice.identifier)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .searchable(text: $searchText, prompt: "言語 / 名前 / identifier")
        .navigationTitle("音声ダンプ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(copied ? "コピー済" : "全件コピー") {
                    UIPasteboard.general.string = Self.dumpText(allVoices)
                    copied = true
                }
            }
        }
    }

    // MARK: - 表示用

    static func qualityLabel(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        quality.displayLabel ?? "default"
    }

    static func authLabel(_ status: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "未確認"
        case .denied:        return "拒否"
        case .unsupported:   return "非対応"
        case .authorized:    return "許可済み"
        @unknown default:    return "不明"
        }
    }

    /// 共有・貼り付け用のプレーンテキスト。
    static func dumpText(_ voices: [AVSpeechSynthesisVoice]) -> String {
        voices
            .map { "\($0.language)\t\(qualityLabel($0.quality))\t\($0.name)\t\($0.identifier)" }
            .joined(separator: "\n")
    }
}

#Preview {
    NavigationStack { VoiceDumpView() }
}

#endif
