//
//  NowPlayingFeature+SleepTimer.swift
//  VoiceYourText
//
//  スリープタイマー（#121）の状態遷移。NowPlayingFeature の switch から呼ばれる。
//

import ComposableArchitecture
import Foundation

extension NowPlayingFeature {

    /// タイマーを設定する（option が nil なら解除）。
    func reduceSetSleepTimer(
        _ state: inout State,
        option: SleepTimerOption?
    ) -> Effect<Action> {
        guard let option else {
            state.sleepTimer = nil
            return .cancel(id: CancelID.sleepTimer)
        }

        state.sleepTimer = SleepTimerState(option: option)

        guard option.totalSeconds != nil else {
            // 「この章の終わりで停止」は時間で切らないのでカウントダウンしない。
            // 読み上げ完了（speechFinished）で停止する既存の経路に委ねる。
            return .cancel(id: CancelID.sleepTimer)
        }

        // 再生中は audio session が生きておりアプリはサスペンドされないため、
        // バックグラウンド／画面ロック中もこのカウントダウンは動き続ける。
        return .run { send in
            while true {
                try await clock.sleep(for: .seconds(1))
                await send(.sleepTimerTicked)
            }
        }
        .cancellable(id: CancelID.sleepTimer, cancelInFlight: true)
    }

    /// カウントダウンを1秒進める。0 になったらタイマーを作動させる。
    func reduceSleepTimerTicked(_ state: inout State) -> Effect<Action> {
        guard var timer = state.sleepTimer,
              let remaining = timer.remainingSeconds else {
            return .none
        }

        let next = remaining - 1
        timer.remainingSeconds = max(0, next)
        state.sleepTimer = timer

        guard next <= 0 else {
            return .none
        }
        return .send(.sleepTimerFired)
    }

    /// タイマー作動。フェードアウトしてから再生を止める。
    func reduceSleepTimerFired(_ state: inout State) -> Effect<Action> {
        state.sleepTimer = nil
        state.isPlaying = false
        nowPlayingClient.updateNowPlayingInfo(state.currentTitle, false)

        // 順序が重要: 先にフェードアウトさせ、そのあとで playback をキャンセルする。
        // 逆順だと playback のキャンセルハンドラが player.stop() を呼び音がぶつ切りになる。
        // 再開できるよう currentTitle / currentText は残す（dismiss はしない）。
        return .concatenate(
            .cancel(id: CancelID.sleepTimer),
            .run { _ in
                NotificationCenter.default.post(name: .sleepTimerFadeOut, object: nil)
                _ = await speechSynthesizer.fadeOutAndStop(Self.sleepTimerFadeOutSeconds)
            },
            .cancel(id: CancelID.playback)
        )
    }
}
