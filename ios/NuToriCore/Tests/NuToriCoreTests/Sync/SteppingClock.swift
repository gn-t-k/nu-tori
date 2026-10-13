import Synchronization

/// テストが進めるまで止まっている単調な時計。待つ側は、進めた先が待ち終わりに届くか、取り消されるまで戻らない
final class SteppingClock: Sendable {
    init() {
        let start = ContinuousClock.now
        self.start = start
        state = Mutex(State(now: start))
    }

    /// 始めてから進めた長さ
    var elapsed: Duration {
        state.withLock { start.duration(to: $0.now) }
    }

    /// 待っている側の数
    var sleeperCount: Int {
        state.withLock { $0.sleepers.count }
    }

    var now: @Sendable () -> ContinuousClock.Instant {
        { self.state.withLock { $0.now } }
    }

    /// 取り消されたら、`Task.sleep` と同じく、その場で `CancellationError` を投げて戻る
    var wait: @Sendable (Duration) async throws -> Void {
        { try await self.sleep(for: $0) }
    }

    /// 待つ側が来るまで待ってから進める。待つ側が来ないまま進めると、進めたあとに来た待つ側が、進めた分だけ長く待つため
    func advance(by duration: Duration) async {
        await withCheckedContinuation { arrival in
            let hasSleeper = state.withLock { state in
                if state.sleepers.isEmpty {
                    state.arrival = arrival
                }
                return !state.sleepers.isEmpty
            }
            if hasSleeper {
                arrival.resume()
            }
        }
        let due = state.withLock { state in
            state.now = state.now.advanced(by: duration)
            let due = state.sleepers.filter { $0.deadline <= state.now }
            state.sleepers.removeAll { $0.deadline <= state.now }
            return due
        }
        for sleeper in due {
            sleeper.resume.resume()
        }
    }

    private func sleep(for duration: Duration) async throws {
        let id = state.withLock { state -> Int in
            state.lastSleeperId += 1
            return state.lastSleeperId
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (sleeper: CheckedContinuation<Void, any Error>) in
                let arrival = state.withLock { state -> CheckedContinuation<Void, Never>? in
                    // 待ち始める前に取り消されていた
                    if state.cancelledBeforeSleeping.remove(id) != nil {
                        sleeper.resume(throwing: CancellationError())
                        return nil
                    }
                    state.sleepers.append(
                        Sleeper(id: id, deadline: state.now.advanced(by: duration), resume: sleeper)
                    )
                    defer { state.arrival = nil }
                    return state.arrival
                }
                arrival?.resume()
            }
        } onCancel: {
            let cancelled = state.withLock { state -> Sleeper? in
                guard let index = state.sleepers.firstIndex(where: { $0.id == id }) else {
                    state.cancelledBeforeSleeping.insert(id)
                    return nil
                }
                return state.sleepers.remove(at: index)
            }
            cancelled?.resume.resume(throwing: CancellationError())
        }
    }

    private struct State {
        var now: ContinuousClock.Instant
        var sleepers: [Sleeper] = []
        var lastSleeperId = 0
        /// 待ち始める前に取り消された待つ側
        var cancelledBeforeSleeping: Set<Int> = []
        /// 待つ側が来るのを待っている `advance(by:)`
        var arrival: CheckedContinuation<Void, Never>?
    }

    private struct Sleeper {
        let id: Int
        let deadline: ContinuousClock.Instant
        let resume: CheckedContinuation<Void, any Error>
    }

    private let start: ContinuousClock.Instant
    private let state: Mutex<State>
}
