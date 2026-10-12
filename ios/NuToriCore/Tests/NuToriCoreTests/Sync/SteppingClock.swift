import Synchronization

/// テストが進めるまで止まっている単調な時計。待つ側は、進めた先が待ち終わりに届くまで戻らない
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

    var now: @Sendable () -> ContinuousClock.Instant {
        { self.state.withLock { $0.now } }
    }

    var wait: @Sendable (Duration) async throws -> Void {
        { duration in
            await withCheckedContinuation { sleeper in
                let arrival = self.state.withLock { state in
                    state.sleepers.append(
                        Sleeper(deadline: state.now.advanced(by: duration), resume: sleeper))
                    defer { state.arrival = nil }
                    return state.arrival
                }
                arrival?.resume()
            }
        }
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

    private struct State {
        var now: ContinuousClock.Instant
        var sleepers: [Sleeper] = []
        /// 待つ側が来るのを待っている `advance(by:)`
        var arrival: CheckedContinuation<Void, Never>?
    }

    private struct Sleeper {
        let deadline: ContinuousClock.Instant
        let resume: CheckedContinuation<Void, Never>
    }

    private let start: ContinuousClock.Instant
    private let state: Mutex<State>
}
