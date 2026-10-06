import Synchronization

/// 待つたびに、待った長さだけ今を進める単調な時計。待った長さを記録する
final class WaitingClock: Sendable {
    init() {
        state = Mutex(State(now: .now, waits: []))
    }

    var waits: [Duration] { state.withLock { $0.waits } }

    var now: @Sendable () -> ContinuousClock.Instant {
        { self.state.withLock { $0.now } }
    }

    var wait: @Sendable (Duration) async throws -> Void {
        { duration in
            self.state.withLock {
                $0.now = $0.now.advanced(by: duration)
                $0.waits.append(duration)
            }
        }
    }

    private struct State {
        var now: ContinuousClock.Instant
        var waits: [Duration]
    }

    private let state: Mutex<State>
}
