import Synchronization

/// 起きた回数。決めた回数に届くまで待てる
final class Tally: Sendable {
    var count: Int {
        state.withLock { $0.count }
    }

    func add() {
        let reached = state.withLock { state in
            state.count += 1
            let reached = state.waiters.filter { $0.count <= state.count }
            state.waiters.removeAll { $0.count <= state.count }
            return reached
        }
        for waiter in reached {
            waiter.resume.resume()
        }
    }

    func reaches(_ count: Int) async {
        await withCheckedContinuation { resume in
            let reached = state.withLock { state in
                if state.count < count {
                    state.waiters.append(Waiter(count: count, resume: resume))
                }
                return state.count >= count
            }
            if reached {
                resume.resume()
            }
        }
    }

    private struct State {
        var count = 0
        var waiters: [Waiter] = []
    }

    private struct Waiter {
        let count: Int
        let resume: CheckedContinuation<Void, Never>
    }

    private let state = Mutex(State())
}
