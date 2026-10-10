import Foundation
import NuToriCore
import Synchronization
import Testing

@Suite("送ったあと、応答を待って取りに行く")
struct ReplyFollowUpTests {
    @Suite("見守る要求がつながっていない文章が、何回か取りに行くうちに応答したとき")
    struct NotWatched {
        let clock: WaitingClock
        let responses: Responses
        let followUp: ReplyFollowUp

        init() {
            clock = WaitingClock()
            responses = Responses(respondingAtSync: 2)
            followUp = ReplyFollowUp(sentAt: clock.now(), now: clock.now, wait: clock.wait)
        }

        @Test("数秒おきに取りに行き、応答を待つ文章が無くなったらやめること")
        func pollsUntilResponded() async throws {
            try await followUp.run(
                awaiting: { responses.awaiting },
                watching: { [] },
                sync: { responses.recordSync() })

            #expect(responses.syncCount == 2)
            #expect(clock.waits == [.seconds(3), .seconds(3)])
        }
    }

    @Suite("応答を待つ文章の見守る要求が、どれもつながっているとき")
    struct AllWatched {
        let clock: WaitingClock
        let sentTextId = UUID()
        let followUp: ReplyFollowUp

        init() {
            clock = WaitingClock()
            followUp = ReplyFollowUp(sentAt: clock.now(), now: clock.now, wait: clock.wait)
        }

        @Test("その文章のためには取りに行かず、送ってから1分でやめること")
        func doesNotPollForWatched() async throws {
            try await followUp.run(
                awaiting: { [sentTextId] },
                watching: { [sentTextId] },
                sync: {
                    Issue.record("取りに行った")
                    return nil
                })

            #expect(clock.waits.reduce(.zero, +) == .seconds(60))
        }
    }

    @Suite("応答がいつまでも届かないとき")
    struct NeverResponded {
        let clock: WaitingClock
        let responses: Responses
        let followUp: ReplyFollowUp

        init() {
            clock = WaitingClock()
            responses = Responses(respondingAtSync: .max)
            followUp = ReplyFollowUp(sentAt: clock.now(), now: clock.now, wait: clock.wait)
        }

        @Test("送ってから1分まで取りに行くこと")
        func stopsAfterOneMinute() async throws {
            try await followUp.run(
                awaiting: { responses.awaiting },
                watching: { [] },
                sync: { responses.recordSync() })

            #expect(responses.syncCount == 20)
        }
    }

    /// 送った文章1つと、取りに行った回数。決めた回数だけ取りに行くと、その文章が応答する
    final class Responses: Sendable {
        let sentTextId = UUID()

        init(respondingAtSync: Int) {
            self.respondingAtSync = respondingAtSync
        }

        var awaiting: Set<UUID> {
            syncCount < respondingAtSync ? [sentTextId] : []
        }

        var syncCount: Int {
            syncs.withLock { $0 }
        }

        func recordSync() -> SyncResult {
            syncs.withLock { $0 += 1 }
            return SyncResult(rejectedWrites: [], ending: .finished)
        }

        private let respondingAtSync: Int
        private let syncs = Mutex(0)
    }
}
