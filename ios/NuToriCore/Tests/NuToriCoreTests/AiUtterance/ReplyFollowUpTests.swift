import Foundation
import NuToriCore
import Synchronization
import Testing

@Suite("送ったあと、応答を待って取りに行く")
struct ReplyFollowUpTests {
    @Suite("見守る要求がつながっていない文章が、何回か取りに行くうちに応答したとき")
    struct NotWatched {
        @Test("数秒おきに取りに行き、応答を待つ文章が無くなったらやめること")
        func pollsUntilResponded() async throws {
            let clock = WaitingClock()
            let id = UUID()
            let awaiting = Mutex<[Set<UUID>]>([[id], [id], []])
            let syncs = Mutex(0)
            try await ReplyFollowUp(sentAt: clock.now(), now: clock.now, wait: clock.wait).run(
                awaiting: { awaiting.withLock { $0.first ?? [] } },
                watching: { [] },
                sync: {
                    syncs.withLock { $0 += 1 }
                    awaiting.withLock { _ = $0.removeFirst() }
                    return SyncResult(rejectedWrites: [], ending: .finished)
                })
            #expect(syncs.withLock { $0 } == 2)
            #expect(clock.waits == [.seconds(3), .seconds(3)])
        }
    }

    @Suite("応答を待つ文章の見守る要求が、どれもつながっているとき")
    struct AllWatched {
        @Test("その文章のためには取りに行かず、送ってから1分でやめること")
        func doesNotPollForWatched() async throws {
            let clock = WaitingClock()
            let id = UUID()
            try await ReplyFollowUp(sentAt: clock.now(), now: clock.now, wait: clock.wait).run(
                awaiting: { [id] },
                watching: { [id] },
                sync: {
                    Issue.record("取りに行った")
                    return nil
                })
            #expect(clock.waits.reduce(.zero, +) == .seconds(60))
        }
    }

    @Suite("応答がいつまでも届かないとき")
    struct NeverResponded {
        @Test("送ってから1分まで取りに行くこと")
        func stopsAfterOneMinute() async throws {
            let clock = WaitingClock()
            let syncs = Mutex(0)
            try await ReplyFollowUp(sentAt: clock.now(), now: clock.now, wait: clock.wait).run(
                awaiting: { [UUID()] },
                watching: { [] },
                sync: {
                    syncs.withLock { $0 += 1 }
                    return SyncResult(rejectedWrites: [], ending: .finished)
                })
            #expect(syncs.withLock { $0 } == 20)
        }
    }
}
