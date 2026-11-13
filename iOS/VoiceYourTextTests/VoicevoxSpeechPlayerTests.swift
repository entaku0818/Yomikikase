import XCTest
@testable import VoiceYourText

@MainActor
private final class FakeOutput: VoicevoxAudioOutput {
    var played: [String] = []
    var failOn: String?
    func play(_ data: Data) async throws {
        let text = String(decoding: data, as: UTF8.self)
        if text == failOn { throw VoicevoxPlaybackError.interrupted }
        played.append(text)
        try await Task.sleep(nanoseconds: 1_000_000)
    }
    func stop() {}
}

private func testConfiguration(maxChars: Int = 300, enabled: Bool = true) -> VoicevoxConfiguration {
    VoicevoxConfiguration(schemaVersion: 1, revision: "test", voicevox: .init(
        enabled: enabled, freeMonthlyChars: 5000, premiumMonthlyChars: 200000, maxRequestChars: maxChars
    ))
}

private let exhaustedUsage = VoicevoxUsage(plan: "free", used: 5000, limit: 5000, remaining: 0, resetAt: .distantFuture)

private func fakeAudio(_ text: String) -> VoicevoxAudio {
    VoicevoxAudio(data: Data(text.utf8), format: "m4a", duration: 1, phrases: [], usage: exhaustedUsage)
}

private actor SynthLog {
    var texts: [String] = []
    func add(_ t: String) { texts.append(t) }
}

@MainActor
final class VoicevoxSpeechPlayerTests: XCTestCase {
    private let usage = exhaustedUsage
    private var cacheDir: URL!

    override func setUp() async throws {
        cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("voicevox-test-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cacheDir)
    }

    private func run(_ player: VoicevoxSpeechPlayer, _ text: String) async -> [VoicevoxSpeechPlayer.Event] {
        await withCheckedContinuation { continuation in
            var events: [VoicevoxSpeechPlayer.Event] = []
            player.play(text: text, speakerId: 14, speedScale: 1) { event in
                events.append(event)
                switch event {
                case .finished, .failed, .quotaExceeded: continuation.resume(returning: events)
                case .sentence: break
                }
            }
        }
    }

    func testPlaysSentencesInOrderAndHighlightsEach() async {
        let output = FakeOutput()
        let player = VoicevoxSpeechPlayer(configuration: { testConfiguration() }, synthesize: { text, _, _ in fakeAudio(text) }, cache: nil, output: output)
        let events = await run(player, "一文目。二文目。")
        XCTAssertEqual(output.played, ["一文目。", "二文目。"])
        XCTAssertEqual(events, [
            .sentence(NSRange(location: 0, length: 4)),
            .sentence(NSRange(location: 4, length: 4)),
            .finished,
        ])
    }

    func testCachedSentenceIsNotSentToServerAgain() async {
        let log = SynthLog()
        let cache = VoicevoxAudioCache(directory: cacheDir)
        let output = FakeOutput()
        let player = VoicevoxSpeechPlayer(configuration: { testConfiguration() }, synthesize: { text, _, _ in
            await log.add(text)
            return fakeAudio(text)
        }, cache: cache, output: output)

        _ = await run(player, "一文目。二文目。")
        _ = await run(player, "一文目。二文目。")
        let sent = await log.texts
        XCTAssertEqual(sent, ["一文目。", "二文目。"], "2回目は保存済みの音声を使い、文字数を使わない")
        XCTAssertEqual(output.played.count, 4)
    }

    func testQuotaExceededReportsWhereToResume() async {
        let output = FakeOutput()
        let player = VoicevoxSpeechPlayer(configuration: { testConfiguration() }, synthesize: { text, _, _ in
            if text == "二文目。" { throw VoicevoxError.quotaExceeded(exhaustedUsage) }
            return fakeAudio(text)
        }, cache: nil, output: output)
        let events = await run(player, "一文目。二文目。三文目。")
        XCTAssertEqual(output.played, ["一文目。"])
        XCTAssertEqual(events.last, .quotaExceeded(usage, resumeAt: 4))
    }

    func testServerErrorReportsWhereToResume() async {
        let player = VoicevoxSpeechPlayer(configuration: { testConfiguration() }, synthesize: { text, _, _ in
            if text == "二文目。" { throw VoicevoxError.server(status: 502, code: "synthesis_failed") }
            return fakeAudio(text)
        }, cache: nil, output: FakeOutput())
        let events = await run(player, "一文目。二文目。")
        XCTAssertEqual(events.last, .failed(resumeAt: 4))
    }

    func testPlaybackErrorReportsWhereToResume() async {
        let output = FakeOutput()
        output.failOn = "二文目。"
        let player = VoicevoxSpeechPlayer(configuration: { testConfiguration() }, synthesize: { text, _, _ in fakeAudio(text) }, cache: nil, output: output)
        let events = await run(player, "一文目。二文目。三文目。")
        XCTAssertEqual(events.last, .failed(resumeAt: 4))
        XCTAssertEqual(output.played, ["一文目。"])
    }

    func testEmptyTextFinishesWithoutCallingServer() async {
        let player = VoicevoxSpeechPlayer(configuration: { testConfiguration() }, synthesize: { _, _, _ in
            XCTFail("記号だけの文章でサーバーを呼んではいけない")
            return fakeAudio("")
        }, cache: nil, output: FakeOutput())
        let events = await run(player, "――\n・・・")
        XCTAssertEqual(events, [.finished])
    }

    func testStopPreventsFurtherEvents() async throws {
        let output = FakeOutput()
        let player = VoicevoxSpeechPlayer(configuration: { testConfiguration() }, synthesize: { text, _, _ in
            try await Task.sleep(nanoseconds: 50_000_000)
            return fakeAudio(text)
        }, cache: nil, output: output)
        var events: [VoicevoxSpeechPlayer.Event] = []
        player.play(text: "一文目。二文目。", speakerId: 14, speedScale: 1) { events.append($0) }
        player.stop()
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(events, [])
        XCTAssertEqual(output.played, [])
        XCTAssertFalse(player.isPlaying)
    }

    func testImmediateStopDoesNotStartSynthesis() async {
        let log = SynthLog()
        let player = VoicevoxSpeechPlayer(configuration: { testConfiguration() }, synthesize: { text, _, _ in
            await log.add(text)
            return fakeAudio(text)
        }, cache: nil, output: FakeOutput())
        player.play(text: "停止する文章。", speakerId: 14, speedScale: 1) { _ in
            XCTFail("Stopped playback must not emit events")
        }
        player.stop()
        // The previous task is queued before the following playback on the main actor.
        _ = await run(player, "新しい文章。")
        let sent = await log.texts
        XCTAssertEqual(sent, ["新しい文章。"])
    }

    func testLateQuotaFailureAfterStopDoesNotEmitOrCancelNewPlayback() async {
        let gate = DelayedQuotaSynthesis()
        let output = FakeOutput()
        let player = VoicevoxSpeechPlayer(configuration: { testConfiguration() }, synthesize: { text, _, _ in
            if text == "古い文章。" { return try await gate.synthesize() }
            return fakeAudio(text)
        }, cache: nil, output: output)
        var oldEvents: [VoicevoxSpeechPlayer.Event] = []
        player.play(text: "古い文章。", speakerId: 14, speedScale: 1) { oldEvents.append($0) }
        await gate.waitUntilStarted()
        player.stop()
        let newEvents = await run(player, "新しい文章。続き。")
        await gate.fail()
        // Drain the cancelled task's completion through the actor queue.
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(oldEvents, [])
        XCTAssertEqual(newEvents.last, .finished)
        XCTAssertEqual(output.played, ["新しい文章。", "続き。"])
    }

    func testCacheKeyDependsOnVoiceAndSpeed() {
        let base = VoicevoxAudioCache.key(text: "こんにちは", speakerId: 14, speedScale: 1)
        XCTAssertEqual(base, VoicevoxAudioCache.key(text: "こんにちは", speakerId: 14, speedScale: 1.0001))
        XCTAssertNotEqual(base, VoicevoxAudioCache.key(text: "こんにちは", speakerId: 3, speedScale: 1))
        XCTAssertNotEqual(base, VoicevoxAudioCache.key(text: "こんにちは", speakerId: 14, speedScale: 1.5))
        XCTAssertNotEqual(base, VoicevoxAudioCache.key(text: "こんばんは", speakerId: 14, speedScale: 1))
    }

    func testServerLimitIsReloadedForEveryPlayback() async {
        let config = ChangingConfiguration()
        let output = FakeOutput()
        let player = VoicevoxSpeechPlayer(configuration: { await config.load() },
            synthesize: { text, _, _ in fakeAudio(text) }, cache: nil, output: output)
        _ = await run(player, "あいうえお")
        await config.setLimit(2)
        _ = await run(player, "あいうえお")
        XCTAssertEqual(output.played, ["あいうえお", "あい", "うえ", "お"])
    }

    func testServerSelectedVoiceIsUsedForSynthesisAndCache() async {
        let selected = SynthLog()
        let cache = VoicevoxAudioCache(directory: cacheDir)
        let player = VoicevoxSpeechPlayer(resolveSpeaker: { _ in 401 }, configuration: { testConfiguration() },
            synthesize: { text, id, _ in
                await selected.add("\(id)")
                return fakeAudio(text)
            }, cache: cache, output: FakeOutput())
        _ = await run(player, "本文。")
        _ = await run(player, "本文。")
        let sent = await selected.texts
        XCTAssertEqual(sent, ["401"])
        XCTAssertNotNil(cache.load(text: "本文。", speakerId: 401, speedScale: 1))
        XCTAssertNil(cache.load(text: "本文。", speakerId: 14, speedScale: 1))
    }

    func testUnavailableCatalogPreventsGeneration() async {
        let player = VoicevoxSpeechPlayer(resolveSpeaker: { _ in throw VoicevoxError.invalidResponse },
            configuration: { testConfiguration() }, synthesize: { _, _, _ in
                XCTFail("Must not generate without a valid server catalog")
                return fakeAudio("")
            }, cache: nil, output: FakeOutput())
        let events = await run(player, "本文。")
        XCTAssertEqual(events, [.failed(resumeAt: 0)])
    }

    func testUnavailableOrDisabledConfigurationNeverSynthesizes() async {
        let configurations: [VoicevoxSpeechPlayer.Configuration] = [
            { throw VoicevoxError.server(status: 503, code: "policy_unavailable") },
            { testConfiguration(enabled: false) },
            { testConfiguration(maxChars: 0) },
        ]
        for config in configurations {
            let player = VoicevoxSpeechPlayer(configuration: config, synthesize: { _, _, _ in
                XCTFail("Invalid or disabled policy must not generate audio")
                return fakeAudio("")
            }, cache: nil, output: FakeOutput())
            let events = await run(player, "文章。")
            XCTAssertEqual(events, [.failed(resumeAt: 0)])
        }
    }

    func testDecodesServerConfigurationWithoutRequiringInternalRules() throws {
        let data = Data(#"{"schemaVersion":1,"revision":"2026-10-30.1","voicevox":{"enabled":true,"freeMonthlyChars":120,"premiumMonthlyChars":800,"maxRequestChars":40}}"#.utf8)
        let config = try JSONDecoder().decode(VoicevoxConfiguration.self, from: data).validated()
        XCTAssertEqual(config.voicevox.maxRequestChars, 40)
        XCTAssertEqual(config.voicevox.premiumMonthlyChars, 800)
    }
}

private actor ChangingConfiguration {
    var limit = 300
    func load() -> VoicevoxConfiguration { testConfiguration(maxChars: limit) }
    func setLimit(_ value: Int) { limit = value }
}

private actor DelayedQuotaSynthesis {
    private var pending: CheckedContinuation<VoicevoxAudio, Error>?
    private var started: CheckedContinuation<Void, Never>?

    func synthesize() async throws -> VoicevoxAudio {
        try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        if pending != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func fail() {
        pending?.resume(throwing: VoicevoxError.quotaExceeded(exhaustedUsage))
        pending = nil
    }
}
