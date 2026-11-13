import XCTest
import ComposableArchitecture
@testable import VoiceYourText

final class TextListeningTests: XCTestCase {
    func testPastePreservesDraftAndMultipleParagraphs() {
        XCTAssertEqual(TextInputDraft.appending(["First\nSecond", "Third"], to: "Existing"), "Existing\nFirst\nSecond\nThird")
        XCTAssertEqual(TextInputDraft.appending(["New"], to: "Existing\n"), "Existing\nNew")
        XCTAssertEqual(TextInputDraft.appending(["日本語😀"], to: ""), "日本語😀")
    }

    func testEmptyPasteDoesNotEraseDraftAndWhitespaceCannotPlay() {
        XCTAssertEqual(TextInputDraft.appending([" \n", ""], to: "Keep me"), "Keep me")
        XCTAssertEqual(TextInputDraft.appending([], to: "Keep me"), "Keep me")
        XCTAssertFalse(TextInputDraft.hasReadableText(" \n\t　"))
        XCTAssertTrue(TextInputDraft.hasReadableText("　こんにちは\n"))
    }

    func testCompletionIsRecordedOnceWithoutContentOrIdentifiers() {
        let events = LockIsolated<[String]>([])
        let analytics = AnalyticsClient(logEvent: { name, params in
            events.withValue { $0.append(name) }
            XCTAssertEqual(Set((params ?? [:]).keys),
                           Set(["source", "content_type", "attempt_id", "engine", "measurement_version", "text_length_bucket"]))
            XCTAssertNotNil(UUID(uuidString: params?["attempt_id"] as? String ?? ""))
            XCTAssertEqual(params?["source"] as? String, "text_input")
            XCTAssertEqual(params?["content_type"] as? String, "text")
        }, setUserProperty: { _, _ in })
        var tracker = ContentPlaybackTracker()
        tracker.request(generation: 1, contentType: "a private filename", analytics: analytics)
        tracker.request(generation: 1, contentType: nil, analytics: analytics)
        tracker.complete(generation: 1, analytics: analytics)
        tracker.complete(generation: 1, analytics: analytics)
        XCTAssertEqual(events.value, ["content_playback_requested", "content_playback_completed"])
    }

    func testStopFailureAndStaleCallbacksDoNotCountAsCompletion() {
        let events = LockIsolated<[String]>([])
        let analytics = AnalyticsClient(logEvent: { name, _ in
            events.withValue { $0.append(name) }
        }, setUserProperty: { _, _ in })
        var tracker = ContentPlaybackTracker()
        tracker.complete(generation: 0, analytics: analytics)
        tracker.request(generation: 1, contentType: nil, analytics: analytics)
        tracker.cancel()
        tracker.complete(generation: 1, analytics: analytics)
        tracker.request(generation: 2, contentType: "epub", analytics: analytics)
        tracker.complete(generation: 1, analytics: analytics)
        tracker.complete(generation: 2, analytics: analytics)
        XCTAssertEqual(events.value, ["content_playback_requested", "content_playback_requested", "content_playback_completed"])
    }

    func testFallbackKeepsAttemptAndIgnoresStaleProgress() {
        let events = LockIsolated<[(String, [String: String])]>([])
        let analytics = AnalyticsClient(logEvent: { name, params in
            events.withValue { $0.append((name, (params ?? [:]).mapValues { String(describing: $0) })) }
        }, setUserProperty: { _, _ in })
        var tracker = ContentPlaybackTracker()
        tracker.request(generation: 1, contentType: "epub", analytics: analytics, now: 100)
        tracker.select(.kokoro, generation: 1, analytics: analytics)
        tracker.failure(.synthesis, generation: 1, recovering: true, analytics: analytics)
        tracker.select(.device, generation: 1, analytics: analytics)
        tracker.progress(generation: 0, evidence: .textHighlight, analytics: analytics, now: 101)
        tracker.progress(generation: 1, evidence: .textHighlight, analytics: analytics, now: 102)
        tracker.progress(generation: 1, evidence: .textHighlight, analytics: analytics, now: 103)
        tracker.complete(generation: 1, analytics: analytics)
        tracker.stop(.viewClosed, analytics: analytics)
        XCTAssertEqual(events.value.map { $0.0 }, [
            "content_playback_requested", "content_playback_engine_selected", "content_playback_failed",
            "content_playback_engine_selected", "content_playback_progress", "content_playback_completed"
        ])
        XCTAssertEqual(Set(events.value.compactMap { $0.1["attempt_id"] }).count, 1)
        XCTAssertEqual(events.value[2].1["engine"], "kokoro")
        XCTAssertEqual(events.value[2].1["recovering"], "1")
        XCTAssertEqual(events.value[4].1["request_to_progress_ms"], "2000")
        XCTAssertEqual(events.value[4].1["engine"], "device")
    }

    func testStopRecordsReasonOnceAndNewAttemptHasNewIdentifier() {
        let events = LockIsolated<[(String, String?, String?)]>([])
        let analytics = AnalyticsClient(logEvent: { name, params in
            events.withValue { $0.append((name, params?["attempt_id"] as? String, params?["reason"] as? String)) }
        }, setUserProperty: { _, _ in })
        var tracker = ContentPlaybackTracker()
        tracker.request(generation: 1, contentType: "scan", analytics: analytics)
        tracker.stop(.viewClosed, analytics: analytics)
        tracker.stop(.user, analytics: analytics)
        tracker.complete(generation: 1, analytics: analytics)
        tracker.request(generation: 2, contentType: "text", analytics: analytics)
        XCTAssertEqual(events.value.count, 3)
        XCTAssertEqual(events.value[1].2, "view_closed")
        XCTAssertNotEqual(events.value[0].1, events.value[2].1)
    }

    func testContractJoinKeyIsStableAndDoesNotContainRevenueCatID() {
        let identifier = "$RCAnonymousID:test"
        let first = SubscriptionAnalyticsIdentity.userID(for: identifier)
        XCTAssertEqual(first.count, 64)
        XCTAssertEqual(first, SubscriptionAnalyticsIdentity.userID(for: identifier))
        XCTAssertNotEqual(first, SubscriptionAnalyticsIdentity.userID(for: "another"))
        XCTAssertFalse(first.contains(identifier))
    }

}
