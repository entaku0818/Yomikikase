import XCTest
@testable import VoiceYourText

@MainActor
final class PremiumStatusRefreshTests: XCTestCase {
    private enum Failure: Error { case offline }

    func testRecoversWithFreshDataAndStopsAfterSuccess() async {
        let refresh = PremiumStatusRefresh()
        var attempts: [Bool] = []
        var delays: [UInt64] = []
        await refresh.run(sleep: { delays.append($0) }) { forceRefresh in
            attempts.append(forceRefresh)
            if attempts.count < 3 { throw Failure.offline }
        }
        XCTAssertEqual(attempts, [false, true, true])
        XCTAssertEqual(delays, [2, 5])
    }

    func testBoundsRetriesAndAllowsLaterForegroundCheck() async {
        let refresh = PremiumStatusRefresh()
        var attempts = 0
        await refresh.run(sleep: { _ in }) { _ in
            attempts += 1
            throw Failure.offline
        }
        XCTAssertEqual(attempts, 4)
        await refresh.run { _ in attempts += 1 }
        XCTAssertEqual(attempts, 5)
    }

    func testSuccessfulCheckDoesNotRetry() async {
        var attempts = 0
        await PremiumStatusRefresh().run(sleep: { _ in XCTFail("Unexpected retry") }) { _ in
            attempts += 1
        }
        XCTAssertEqual(attempts, 1)
    }

    func testConcurrentTriggerDoesNotStartAnotherCheck() async {
        let refresh = PremiumStatusRefresh()
        await refresh.run { _ in
            await refresh.run { _ in XCTFail("Duplicate check") }
        }
    }

    func testCancellationDuringDelayStopsRetries() async {
        var attempts = 0
        await PremiumStatusRefresh().run(sleep: { _ in throw CancellationError() }) { _ in
            attempts += 1
            throw Failure.offline
        }
        XCTAssertEqual(attempts, 1)
    }
}
