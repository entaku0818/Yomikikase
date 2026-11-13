# First content listening — 2026-10-27

## Problem and change

The onboarding sample CTA and ja/en sample matching were already implemented in `ff8ed24`. This change focuses on the next real-content action in `TextInputView`.

The old “Save” button already saved and started playback. The edit screen now has a prominent “Save and listen” action below the voice controls, with translations for all ten supported app languages. Long text retains the existing play-without-saving label and premium limit checks. Whitespace-only drafts cannot start playback.

A system Paste button gives an explicit way to bring copied content into the editor. It appends to the existing draft, preserving its contents. Clipboard contents are not read automatically. Pricing, trial eligibility and paywall timing are unchanged.

## Measurement correction

The main `TextInputView.completeSpeaking()` path did not emit `speech_completed`. The legacy `SpeechView` reducer and PDF reader emitted that event. Consequently, the historical 18-user `speech_completed` result in the October 21 analysis is not a count of all real-content listeners. The previous onboarding report already cautioned that coverage was partial; this inspection identifies a major missing path.

New events for this screen:

- `content_playback_requested`: an accepted play/resume request, once per playback generation. This does not prove that audio was audible.
- `content_playback_completed`: the requested text or remaining portion reached a successful completion callback, once per playback generation. Resuming and completing a remainder is not evidence that the entire document was listened to in one session.

Both events contain only `source=text_input` and an allowlisted `content_type` (`text`, `scan`, `epub`, or `aozora`). Unknown types map to `text`. No text, document title, file identifier or clipboard data is sent. PDF-native playback continues to use its existing measurement.

Stops, errors, quota interruption and late/duplicate callbacks must not count as completion. Stored/Kokoro audio completion notifications are scoped to the current player and generation and must carry a successful finish flag. An audio-session or player-start failure releases the playing state so the user can retry.

## Evaluation after release

Record the actual published version/date. Use iOS, that app version, and equal observation windows. Inspect event delivery before interpreting reports. First measure ordered, period-unique-user funnels:

1. `onboarding_completed → content_playback_requested`.
2. `content_playback_requested → content_playback_completed`.
3. Subsequent use on a later day and RevenueCat trial outcome, reported separately.

Do not compare the new event counts directly with historical `speech_completed`: coverage changed. Do not sum daily users or interpret more completion events alone as increased paid conversion. The October 27 HQ snapshot still shows seven trial starts and zero new paid users in the latest 30 days, with trial outcomes potentially pending.

## Validation

Validated locally with Xcode 27.1 on CI-VoiceYourText (iOS 27.0):

- App and test targets built successfully.
- OnboardingReducerTests: 14 passed; PlaybackResumeTests: 14 passed.
- TextListeningTests: 4 passed (paste preservation, whitespace gating, successful completion once, cancelled/stale callbacks).
- Japanese and English UI tests: 2 passed. Both verify empty/whitespace gating, a visible Paste control, a reachable listening CTA while editing, and transition to the player after saving. Paste payload merging is covered by unit tests; native clipboard permission interaction is not automated here.
- SwiftLint: exit 0, 0 errors, 36 style warnings in the edited production files. `git diff --check` passed.
- The UI tests fix AppLaunchCount at zero to keep the unrelated second-launch review prompt out of this first-listen scenario.

Screenshots: [Japanese](screenshots/first-listening-ja.png), [English](screenshots/first-listening-en.png).

Xcode stalled while collecting simulator diagnostics after a successful run. The final run used `test-without-building -collect-test-diagnostics never` and exited 0 (`TEST EXECUTE SUCCEEDED`).

No release has been submitted by this task. Physical-device audio checks, GA4 event-delivery checks and post-publication business results remain unverified.
