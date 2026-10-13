import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("送った文章の状態のキャッシュの行")
struct CachedSentTextStatusCacheTests {
    typealias Status = SentTextStatusSyncing.Status

    /// すべての読み分けと応答の状態を、送った文章ごとに1つずつ保存してあるキャッシュ。置き場は、キャッシュを使うあいだ持っておく
    @MainActor static func filledCache() throws -> (
        store: SwiftDataSyncStore, cache: SwiftDataKeyedRecordCache<CachedSentTextStatus>,
        failed: Status, others: Set<Status>
    ) {
        let store = try SwiftDataSyncStore(inMemory: true)
        let cache = SwiftDataKeyedRecordCache<CachedSentTextStatus>(
            context: store.container.mainContext)
        let failed = Status(
            sentTextId: UUID(),
            status: .init(classification: .conversation, reply: .failed(.retriesExhausted)))
        let others: Set<Status> = [
            Status(
                sentTextId: UUID(), status: .init(classification: .pending, reply: .notRequested)),
            Status(sentTextId: UUID(), status: .init(classification: .meal, reply: .notRequested)),
            Status(
                sentTextId: UUID(), status: .init(classification: .conversation, reply: .awaiting)),
            Status(
                sentTextId: UUID(), status: .init(classification: .conversation, reply: .replied)),
            Status(
                sentTextId: UUID(), status: .init(classification: .conversation, reply: .halted)),
            Status(
                sentTextId: UUID(),
                status: .init(classification: .conversation, reply: .failed(.badRequest))),
        ]
        try cache.upsert(failed)
        for status in others {
            try cache.upsert(status)
        }
        try cache.context.save()
        return (store, cache, failed, others)
    }

    @Suite("すべての読み分けと応答の状態を、送った文章ごとに1つずつ足したとき")
    @MainActor
    struct Filled {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedSentTextStatus>
        let failed: Status
        let others: Set<Status>

        init() throws {
            (store, cache, failed, others) = try CachedSentTextStatusCacheTests.filledCache()
        }

        @Test("足した状態と同じ状態を、どの読み分けと応答の状態でも読めること")
        func readsBackSameRecords() throws {
            #expect(Set(try cache.savedRecords()) == others.union([failed]))
        }

        @Suite("返事を作れなかった状態と同じ送った文章の、返事が来た状態を足すとき")
        @MainActor
        struct UpsertingRepliedOverFailed {
            let store: SwiftDataSyncStore
            let cache: SwiftDataKeyedRecordCache<CachedSentTextStatus>
            let others: Set<Status>
            let replied: Status

            init() throws {
                let filled = try CachedSentTextStatusCacheTests.filledCache()
                store = filled.store
                cache = filled.cache
                others = filled.others
                replied = Status(
                    sentTextId: filled.failed.sentTextId,
                    status: .init(classification: .conversation, reply: .replied))
            }

            @Test("行を増やさず、作れなかった理由が無くなること")
            func replacesAndDropsFailureReason() throws {
                try cache.upsert(replied)

                let saved = try cache.savedRecords()
                #expect(saved.count == 7)
                #expect(Set(saved) == others.union([replied]))
            }
        }

        @Test("送った文章の ID で消すと、その文章の状態の行だけが無くなること")
        func removesBySentTextId() throws {
            try cache.remove(id: failed.sentTextId)

            #expect(Set(try cache.savedRecords()) == others)
        }

        @Test("すべて消すと、行が無くなること")
        func removesAll() throws {
            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }
    }

    @Suite("知らない読み分け・知らない応答の状態・知らない作れなかった理由の行があるとき")
    @MainActor
    struct Unreadable {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedSentTextStatus>
        let readable: Status

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let context = store.container.mainContext
            cache = SwiftDataKeyedRecordCache(context: context)
            readable = Status(
                sentTextId: UUID(), status: .init(classification: .conversation, reply: .replied))
            let unknownClassification = Status(
                sentTextId: UUID(), status: .init(classification: .meal, reply: .notRequested))
            let unknownReply = Status(
                sentTextId: UUID(), status: .init(classification: .conversation, reply: .awaiting))
            let unknownReason = Status(
                sentTextId: UUID(),
                status: .init(classification: .conversation, reply: .failed(.badRequest)))
            for status in [readable, unknownClassification, unknownReply, unknownReason] {
                try cache.upsert(status)
            }
            try #require(
                try CachedSentTextStatus.find(id: unknownClassification.sentTextId, in: context)
            ).classification = "weight"
            try #require(try CachedSentTextStatus.find(id: unknownReply.sentTextId, in: context))
                .replyStatus = "streaming"
            try #require(try CachedSentTextStatus.find(id: unknownReason.sentTextId, in: context))
                .replyFailureReason = "provider_down"
            try context.save()
        }

        @Test("読めない行を飛ばし、読める状態だけを読むこと")
        func skipsUnreadableRows() throws {
            #expect(try cache.savedRecords() == [readable])
        }
    }
}
