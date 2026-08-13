//
//  SleepTimerOption.swift
//  VoiceYourText
//
//  スリープタイマー（「ながら聴き」層向け・#121）のモデル。
//

import Foundation

/// スリープタイマーで選べる停止条件。
enum SleepTimerOption: Equatable, Hashable, Identifiable {
    /// 指定分数の経過で停止する。
    case minutes(Int)
    /// いま読み上げている項目（章／ファイル）を読み終えたら停止する。
    case endOfChapter

    /// プレイヤーのメニューに並べる順。
    static let presets: [SleepTimerOption] = [
        .minutes(5), .minutes(10), .minutes(15),
        .minutes(30), .minutes(45), .minutes(60),
        .endOfChapter
    ]

    var id: String {
        switch self {
        case .minutes(let minutes):
            return "minutes-\(minutes)"
        case .endOfChapter:
            return "endOfChapter"
        }
    }

    /// カウントダウンの総秒数。`endOfChapter` は時間で切らないため nil。
    var totalSeconds: Int? {
        switch self {
        case .minutes(let minutes):
            return minutes * 60
        case .endOfChapter:
            return nil
        }
    }

    /// メニューに出す文言。
    var title: String {
        switch self {
        case .minutes(let minutes):
            return String(format: String(localized: "%d分後に停止"), minutes)
        case .endOfChapter:
            return String(localized: "この章の終わりで停止")
        }
    }
}

/// 作動中のスリープタイマー。
struct SleepTimerState: Equatable {
    var option: SleepTimerOption
    /// 残り秒数。`endOfChapter` では時間で切らないため nil。
    var remainingSeconds: Int?

    init(option: SleepTimerOption) {
        self.option = option
        self.remainingSeconds = option.totalSeconds
    }

    init(option: SleepTimerOption, remainingSeconds: Int?) {
        self.option = option
        self.remainingSeconds = remainingSeconds
    }

    /// プレイヤーに出す残り時間表示（`5:00` / 章末指定なら文言）。
    var displayText: String {
        guard let remainingSeconds else {
            return String(localized: "章の終わりまで")
        }
        return Self.formattedRemaining(remainingSeconds)
    }

    /// 残り秒数を `m:ss`（1時間以上なら `h:mm:ss`）に整形する。
    static func formattedRemaining(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let secs = clamped % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

extension Notification.Name {
    /// スリープタイマー作動時のフェードアウト要求。
    /// NowPlayingFeature が自前で持つ AVAudioPlayer（クラウドTTS再生）は
    /// SpeechSynthesizerClient の管理外にあるため、通知で音量フェードを依頼する。
    static let sleepTimerFadeOut = Notification.Name("SleepTimerFadeOut")
}
