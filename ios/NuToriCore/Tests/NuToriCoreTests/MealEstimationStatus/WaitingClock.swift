import Foundation
import Synchronization

/// 待つたびに、待った長さだけ今を進める時計。待った長さを記録する
final class WaitingClock: Sendable {
    init(start: Date) {
        state = Mutex(State(now: start, waits: []))
    }

    var waits: [Duration] { state.withLock { $0.waits } }

    var now: @Sendable () -> Date {
        { self.state.withLock { $0.now } }
    }

    var wait: @Sendable (Duration) async throws -> Void {
        { duration in
            self.state.withLock {
                $0.now = $0.now.addingTimeInterval(TimeInterval(duration.components.seconds))
                $0.waits.append(duration)
            }
        }
    }

    private struct State {
        var now: Date
        var waits: [Duration]
    }

    private let state: Mutex<State>
}
