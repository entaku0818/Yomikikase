# Onboarding demo measurement (#162)

## Change and hypothesis

The demo's main button offers a short sample (about ten seconds). Skip remains available as a secondary text action. Japanese app language uses Japanese sample text and a ja-JP voice; English and other app languages use the same English sample text with an en-US voice. The displayed PDF and spoken body share one sample definition. Unsupported sample languages fall back to English, not Japanese text spoken with an unrelated default voice.

The baseline is 189 onboarding entrants → 60 demo starts → 57 demo completions, from iOS GA4 for 2026-09-20 through 2026-10-19. Onboarding completion is separately 169/189 (89.4%). Demo nonparticipation is not app abandonment.

## Event contract

- `onboarding_step_view`: one event per step per onboarding State lifetime. Reappearance does not duplicate a step; step changes are explicitly observed.
- `onboarding_demo_played`: first play request per onboarding State lifetime, with `demo_type=pdf` and `sample_language`. It records the request, not guaranteed audible output.
- `onboarding_demo_completed`: first valid speech completion, with duration and sample language. Stopping or skipping invalidates the current utterance; late callbacks must not count as completion.
- `onboarding_skipped`: skips the current step, not the whole application. Repeated taps after reaching the final step are ignored.
- `onboarding_completed`: emitted once per onboarding State lifetime; `completed_demo=1` means the demo reached speech completion. Completing without the demo remains possible.
- Existing `speech_completed` records actual user content completion, with `source=text` or the existing `source=pdf`. It is separate from the demo events and does not contain text or PDF contents. It measures completion, not every play attempt, and does not cover every player path in the app.

A new onboarding State (for example after killing the app before finishing) can emit events again. Period-unique-user funnels, rather than raw event counts, are the primary comparison.

## Repeatable evaluation

GA4 property: `431236332`; platform iOS; JST; fixed inclusive dates. Record actual publication date and version before evaluating. At publication +7 and +14 days, compare equal-length windows and show sample size, app version and sample language where available.

Use closed ordered funnels allowing intermediate events:

1. `onboarding_step_view → onboarding_demo_played → onboarding_demo_completed`.
2. `onboarding_step_view → onboarding_completed` (guardrail).
3. `onboarding_completed → speech_completed` (user-content completion).

Do not sum daily users or assume separate funnels are mutually exclusive cohorts. Repeat-user retention and RevenueCat paid conversion are separate follow-up outcomes. The working goal is demo start rate ≥45%, while maintaining onboarding completion near 89%; it is not a statistical significance threshold. If traffic is too small, extend observation instead of declaring success after one week.

Before parameter breakdowns, inspect GA4 Data API metadata. As of the 2026-10-21 analysis, no custom dimensions were registered, and raw `step` filtering returned an unsupported-parameter error. Delivery in DebugView does not prove processed report availability. Registering event-scoped dimensions, their processing delay, and new-version report verification are separate follow-ups; do not infer missing/unsupported data means zero. App version and platform are standard dimensions. Never infer language solely from country.

## Verification and release tracking

Reducer tests cover play/stop, duplicate appearances/taps, late completion after skip, final completion without listening, and matching ja/en sample PDF data. UI tests cover Japanese stop/skip and English full playback, with screenshots attached to test results. Execution results must be recorded separately from test definitions.

Actual publication date/version: pending. DebugView and processed new-version analytics: pending. No pricing, advertising spend or App Store submission is part of this implementation.

## Validation — 2026-10-21

Xcode 27 / CI-VoiceYourText simulator:

- OnboardingReducerTests: 14 passed, 0 failures (including PDF/sample checks).
- Japanese and English UI flows: 4 passed, 0 failures. Both languages exercised stop/skip and full demo completion followed by finishing onboarding.
- App/test builds passed. Changed-file SwiftLint exited 0 with existing style warnings. `git diff --check` passed.
- Visual inspection: the sample-play button is prominent and Skip remains visible. Screenshots: [Japanese](screenshots/onboarding-demo-ja.png), [English](screenshots/onboarding-demo-en.png).

UI tests verify the synthesizer completion callback and screen transitions; they are not acoustic-quality verification on a physical device. GA4 DebugView/processed-event evidence and post-publication results remain open follow-ups. Filter test-device traffic out of business evaluation.

## Follow-up — onboarding localization, 2026-10-27

The welcome tags and feature descriptions were passed to `Text` as runtime strings, so they were displayed literally instead of being looked up in the string catalog. The feature-row parameters now use `LocalizedStringKey`, and the tags explicitly convert their keys. Ten missing catalog entries now have Japanese and English translations; the existing Google Drive translation is reused.

The four ja/en onboarding UI flows now assert the welcome tags and all feature titles/descriptions as well as stop, skip, demo completion and finishing onboarding. This follow-up preserves the sample text, playback behavior and event names. It does not complete the pending GA4 or post-publication evaluation requirements of #162.

Validation: Xcode 27.1 / iOS 27.0 Simulator build passed; 14 OnboardingReducerTests and all four ja/en UI flows passed (0 failures). Changed-file SwiftLint passed with existing style warnings; diff whitespace check passed.
