import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("送った文章の状態の同期の形")
struct SentTextStatusSyncingTests {
    typealias Status = SentTextStatusSyncing.Status

    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = SentTextStatusSyncing()
        let cache = MemoryKeyedRecordCache<Status, UUID>(id: \.sentTextId)
        /// どちらの送った文章も届いていない
        let pendingSentTextId = UUID()
        let mealSentTextId = UUID()

        init() throws {
            try syncing.apply(
                [
                    .sentTextStatus(
                        .init(
                            sentTextId: pendingSentTextId, classification: .pending,
                            reply: .notRequested)),
                    .sentTextStatus(
                        .init(
                            sentTextId: mealSentTextId, classification: .meal,
                            reply: .notRequested)),
                ], to: cache)
        }

        @Test("送った文章が無くても、届いた状態が送った文章の ID ごとにキャッシュに入ること")
        func storesArrivedStatuses() {
            #expect(
                Set(cache.all()) == [
                    Status(
                        sentTextId: pendingSentTextId,
                        status: SentTextStatus(classification: .pending, reply: .notRequested)),
                    Status(
                        sentTextId: mealSentTextId,
                        status: SentTextStatus(classification: .meal, reply: .notRequested)),
                ])
        }

        @Test("同じ送った文章の状態が続けて届いたら、あとに届いた状態にすること")
        func keepsLatestStatus() throws {
            try syncing.apply(
                [
                    .sentTextStatus(
                        .init(
                            sentTextId: pendingSentTextId, classification: .conversation,
                            reply: .awaiting)),
                    .sentTextStatus(
                        .init(
                            sentTextId: pendingSentTextId, classification: .conversation,
                            reply: .failed(.retriesExhausted))),
                ], to: cache)

            #expect(
                cache.all().first { $0.sentTextId == pendingSentTextId }?.status
                    == SentTextStatus(
                        classification: .conversation, reply: .failed(.retriesExhausted)))
            #expect(cache.all().count == 2)
        }

        @Test("送った文章を外す変更は、状態を消さないこと")
        func skipsSentTextRemoval() throws {
            try syncing.apply([.sentTextRemoval(sentTextId: pendingSentTextId)], to: cache)

            #expect(cache.all().count == 2)
        }

        @Test("空にすると、状態がキャッシュから無くなること")
        func erases() throws {
            try syncing.erase(cache)

            #expect(cache.all().isEmpty)
        }
    }
}
