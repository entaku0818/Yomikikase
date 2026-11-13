import XCTest
@testable import VoiceYourText

final class KokoroPhonemeChunkerTests: XCTestCase {
    func testShortInputIsUnchanged() {
        let text = "koɲɲitɕiwa. kʲoːwa iːteŋkʲidesɯ."
        XCTAssertEqual(KokoroPhonemeChunker.chunks(text), [text])
    }

    func testSentenceBoundaryKeepsClosingQuoteAndSpace() {
        let sentence = String(repeating: "a", count: 150) + ".\" "
        let text = sentence + String(repeating: "i", count: 90)
        XCTAssertEqual(KokoroPhonemeChunker.chunks(text), [sentence, String(repeating: "i", count: 90)])
    }

    func testShortSentencesAreGrouped() {
        let text = String(repeating: "a. ", count: 90)
        let chunks = KokoroPhonemeChunker.chunks(text)
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks.joined(), text)
        XCTAssertTrue(chunks.allSatisfy { $0.count >= 20 && $0.count <= 200 })
    }

    func testFallsBackToPhraseBoundaryWhenSentenceIsLong() {
        let phrase = String(repeating: "a", count: 140) + " "
        let rest = String(repeating: "i", count: 120)
        XCTAssertEqual(KokoroPhonemeChunker.chunks(phrase + rest), [phrase, rest])
    }

    func testLongUnpunctuatedInputIsBoundedAndNeverDropped() {
        let text = String(repeating: "tɕoː", count: 400)
        let chunks = KokoroPhonemeChunker.chunks(text)
        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertEqual(chunks.joined(), text)
        XCTAssertTrue(chunks.allSatisfy { !$0.isEmpty && $0.count <= 200 })
    }

    func testTinyFinalTailIsBalanced() {
        let text = String(repeating: "a", count: 201)
        XCTAssertEqual(KokoroPhonemeChunker.chunks(text).map(\.count), [100, 101])
    }

    func testExactLimitStaysIntact() {
        let text = String(repeating: "a", count: 200)
        XCTAssertEqual(KokoroPhonemeChunker.chunks(text), [text])
    }

    func testJapaneseReadingsAndPunctuationSurviveLongInput() throws {
        let text = String(repeating: "今日は、10月29日です。東京から大阪へ向かいます。", count: 20)
        let (phonemes, _) = try JapaneseG2PProcessor().process(input: text)
        let chunks = KokoroPhonemeChunker.chunks(phonemes)
        XCTAssertGreaterThan(phonemes.count, 510)
        XCTAssertEqual(chunks.joined(), phonemes)
        XCTAssertTrue(chunks.allSatisfy { $0.count <= 200 })
    }

    func testAudioIsConcatenatedInOrderWithoutExtraSilence() throws {
        let text = String(repeating: "a", count: 201)
        var rendered: [String] = []
        let samples = try KokoroPhonemeChunker.synthesize(text) { chunk in
            rendered.append(chunk)
            return rendered.count == 1 ? [0.1, 0.2] : [0.3, 0.4]
        }
        XCTAssertEqual(rendered.joined(), text)
        XCTAssertEqual(samples, [0.1, 0.2, 0.3, 0.4])
    }

    func testFailureDoesNotReturnTruncatedAudioOrContinue() {
        enum ExpectedFailure: Error { case synthesis }
        var renderedCount = 0
        XCTAssertThrowsError(try KokoroPhonemeChunker.synthesize(String(repeating: "a", count: 600)) { _ in
            renderedCount += 1
            if renderedCount == 2 { throw ExpectedFailure.synthesis }
            return [0.1]
        }) { error in
            XCTAssertTrue(error is ExpectedFailure)
        }
        XCTAssertEqual(renderedCount, 2)
    }

    func testCancellationStopsBeforeNextChunk() async {
        let task = Task {
            var renderedCount = 0
            do {
                _ = try KokoroPhonemeChunker.synthesize(String(repeating: "a", count: 600)) { _ in
                    renderedCount += 1
                    withUnsafeCurrentTask { $0?.cancel() }
                    return [0.1]
                }
                XCTFail("Cancelled synthesis must not return audio")
            } catch {
                XCTAssertTrue(error is CancellationError)
            }
            XCTAssertEqual(renderedCount, 1)
        }
        await task.value
    }

    func testCancellationDuringFinalChunkDoesNotReturnAudio() async {
        let task = Task {
            do {
                _ = try KokoroPhonemeChunker.synthesize("koɲɲitɕiwa") { _ in
                    withUnsafeCurrentTask { $0?.cancel() }
                    return [0.1]
                }
                XCTFail("Cancellation must also discard the final chunk")
            } catch {
                XCTAssertTrue(error is CancellationError)
            }
        }
        await task.value
    }

    func testEmptyInputDoesNotInvokeModel() throws {
        let samples = try KokoroPhonemeChunker.synthesize("") { _ in
            XCTFail("Empty phonemes must not reach inference")
            return [0.1]
        }
        XCTAssertTrue(samples.isEmpty)
    }
}
