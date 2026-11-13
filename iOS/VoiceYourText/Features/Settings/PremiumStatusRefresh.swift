import Foundation

/// Bounds retries and coalesces startup/foreground refreshes into one running check.
@MainActor
final class PremiumStatusRefresh {
    private var isRunning = false

    func run(
        retryDelays: [UInt64] = [2, 5, 15],
        sleep: (UInt64) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
        },
        check: (_ forceRefresh: Bool) async throws -> Void
    ) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        for attempt in 0...retryDelays.count {
            do {
                try Task.checkCancellation()
                if attempt > 0 {
                    try await sleep(retryDelays[attempt - 1])
                }
                try Task.checkCancellation()
            } catch {
                return
            }
            do {
                try await check(attempt > 0)
                return
            } catch is CancellationError {
                return
            } catch {
                // Unverified responses never grant access. Retry using fresh server data.
                continue
            }
        }
    }
}
