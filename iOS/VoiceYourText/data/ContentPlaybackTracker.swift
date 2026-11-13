import Foundation

/// Playback evidence, not proof that the user heard audio. No text, titles or file IDs are sent.
struct ContentPlaybackTracker {
    enum Engine: String { case device, kokoro, voicevox, savedAudio = "saved_audio", resumedAudio = "resumed_audio" }
    enum ProgressEvidence: String { case playerAccepted = "player_accepted", textHighlight = "text_highlight", sentenceScheduled = "sentence_scheduled" }
    enum Failure: String { case audioSession = "audio_session", synthesis, audioPlayer = "audio_player", quota }
    enum StopReason: String { case user, viewClosed = "view_closed", interrupted }

    private var activeGeneration: Int?
    private var contentType = "text"
    private var lengthBucket = "unknown"
    private var attemptID = ""
    private var requestedAt: TimeInterval = 0
    private var engine: Engine?
    private var recordedProgress = false

    mutating func request(
        generation: Int, contentType: String?, analytics: AnalyticsClient, characterCount: Int? = nil,
        now: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        guard activeGeneration != generation else {
            return
        }
        activeGeneration = generation
        let supported = ["text", "scan", "epub", "aozora"]
        self.contentType = contentType.flatMap { supported.contains($0) ? $0 : nil } ?? "text"
        if let characterCount {
            lengthBucket = characterCount <= 500 ? "up_to_500" : characterCount <= 4000 ? "501_to_4000" : "over_4000"
        } else {
            lengthBucket = "unknown"
        }
        attemptID = UUID().uuidString
        requestedAt = now
        engine = nil
        recordedProgress = false
        analytics.logEvent("content_playback_requested", parameters)
    }

    mutating func select(_ engine: Engine, generation: Int, analytics: AnalyticsClient) {
        guard activeGeneration == generation, self.engine != engine else {
            return
        }
        self.engine = engine
        recordedProgress = false
        analytics.logEvent("content_playback_engine_selected", parameters)
    }

    /// First playback/highlight callback for the selected engine. AVAudioPlayer uses play() acceptance.
    mutating func progress(
        generation: Int, evidence: ProgressEvidence, analytics: AnalyticsClient,
        now: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        guard activeGeneration == generation, !recordedProgress else {
            return
        }
        recordedProgress = true
        var values = parameters
        values["evidence"] = evidence.rawValue
        values["request_to_progress_ms"] = Int(max(0, min(now - requestedAt, 86_400)) * 1000)
        analytics.logEvent("content_playback_progress", values)
    }

    func failure(_ reason: Failure, generation: Int, recovering: Bool, analytics: AnalyticsClient) {
        guard activeGeneration == generation else {
            return
        }
        var values = parameters
        values["reason"] = reason.rawValue
        values["recovering"] = recovering ? 1 : 0
        analytics.logEvent("content_playback_failed", values)
    }

    mutating func complete(generation: Int, analytics: AnalyticsClient) {
        guard activeGeneration == generation else {
            return
        }
        analytics.logEvent("content_playback_completed", parameters)
        activeGeneration = nil
    }

    mutating func stop(_ reason: StopReason, analytics: AnalyticsClient) {
        guard activeGeneration != nil else {
            return
        }
        var values = parameters
        values["reason"] = reason.rawValue
        analytics.logEvent("content_playback_stopped", values)
        cancel()
    }

    mutating func cancel() { activeGeneration = nil }

    private var parameters: [String: Any] {
        ["source": "text_input", "content_type": contentType, "attempt_id": attemptID,
         "engine": engine?.rawValue ?? "unselected", "measurement_version": 1, "text_length_bucket": lengthBucket]
    }
}
