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
        let player = VoicevoxSpeechPlayer(synthesize: { text, _, _ in fakeAudio(text) }, cache: nil, output: output)
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
        let player = VoicevoxSpeechPlayer(synthesize: { text, _, _ in
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
        let player = VoicevoxSpeechPlayer(synthesize: { text, _, _ in
            if text == "二文目。" { throw VoicevoxError.quotaExceeded(exhaustedUsage) }
            return fakeAudio(text)
        }, cache: nil, output: output)
        let events = await run(player, "一文目。二文目。三文目。")
        XCTAssertEqual(output.played, ["一文目。"])
        XCTAssertEqual(events.last, .quotaExceeded(usage, resumeAt: 4))
    }

    func testServerErrorReportsWhereToResume() async {
        let player = VoicevoxSpeechPlayer(synthesize: { text, _, _ in
            if text == "二文目。" { throw VoicevoxError.server(status: 502, code: "synthesis_failed") }
            return fakeAudio(text)
        }, cache: nil, output: FakeOutput())
        let events = await run(player, "一文目。二文目。")
        XCTAssertEqual(events.last, .failed(resumeAt: 4))
    }

    func testPlaybackErrorReportsWhereToResume() async {
        let output = FakeOutput()
        output.failOn = "二文目。"
        let player = VoicevoxSpeechPlayer(synthesize: { text, _, _ in fakeAudio(text) }, cache: nil, output: output)
        let events = await run(player, "一文目。二文目。三文目。")
        XCTAssertEqual(events.last, .failed(resumeAt: 4))
        XCTAssertEqual(output.played, ["一文目。"])
    }

    func testEmptyTextFinishesWithoutCallingServer() async {
        let player = VoicevoxSpeechPlayer(synthesize: { _, _, _ in
            XCTFail("記号だけの文章でサーバーを呼んではいけない")
            return fakeAudio("")
        }, cache: nil, output: FakeOutput())
        let events = await run(player, "――\n・・・")
        XCTAssertEqual(events, [.finished])
    }

    func testStopPreventsFurtherEvents() async throws {
        let output = FakeOutput()
        let player = VoicevoxSpeechPlayer(synthesize: { text, _, _ in
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

    func testCacheKeyDependsOnVoiceAndSpeed() {
        let base = VoicevoxAudioCache.key(text: "こんにちは", speakerId: 14, speedScale: 1)
        XCTAssertEqual(base, VoicevoxAudioCache.key(text: "こんにちは", speakerId: 14, speedScale: 1.0001))
        XCTAssertNotEqual(base, VoicevoxAudioCache.key(text: "こんにちは", speakerId: 3, speedScale: 1))
        XCTAssertNotEqual(base, VoicevoxAudioCache.key(text: "こんにちは", speakerId: 14, speedScale: 1.5))
        XCTAssertNotEqual(base, VoicevoxAudioCache.key(text: "こんばんは", speakerId: 14, speedScale: 1))
    }
}
