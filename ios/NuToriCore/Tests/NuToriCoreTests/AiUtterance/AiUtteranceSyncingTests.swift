import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("返事の同期の形")
struct AiUtteranceSyncingTests {
    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = AiUtteranceSyncing()
        let cache: MemoryKeyedRecordCache<AiUtterance, UUID>
        let first: AiUtterance
        let second: AiUtterance

        init() throws {
            (cache, first, second) = try Self.appliedCache()
        }

        /// 返事を2件当てたキャッシュ。応える送った文章は届いていない
        static func appliedCache() throws -> (
            cache: MemoryKeyedRecordCache<AiUtterance, UUID>, first: AiUtterance,
            second: AiUtterance
        ) {
            let cache = MemoryKeyedRecordCache<AiUtterance, UUID>(id: \.id)
            let first = AiUtterance(
                id: UUID(), body: "よく食べました", sentTextId: UUID(), mealIds: [])
            let second = AiUtterance(
                id: UUID(), body: "昼はこちらです", sentTextId: UUID(), mealIds: [UUID(), UUID()])
            try AiUtteranceSyncing().apply(
                [first, second].map { .aiUtterance(synced($0)) }, to: cache)
            return (cache, first, second)
        }

        static func synced(_ utterance: AiUtterance) -> SyncedAiUtterance {
            SyncedAiUtterance(
                id: utterance.id, body: utterance.body, sentTextId: utterance.sentTextId,
                mealIds: utterance.mealIds)
        }

        @Test("送った文章が無くても、届いた返事が今の値でキャッシュに入ること")
        func storesArrivedUtterances() {
            #expect(Set(cache.all()) == [first, second])
        }

        @Suite("同じ返事が届き直したとき")
        struct ArrivedAgain {
            let syncing = AiUtteranceSyncing()
            let cache: MemoryKeyedRecordCache<AiUtterance, UUID>
            let second: AiUtterance
            let arrivedAgain: AiUtterance

            init() throws {
                let applied = try Applying.appliedCache()
                cache = applied.cache
                second = applied.second
                arrivedAgain = AiUtterance(
                    id: applied.first.id, body: "よく食べましたね",
                    sentTextId: applied.first.sentTextId, mealIds: [UUID()])
            }

            @Test("キャッシュの返事をその値にそろえること")
            func overwritesWithArrivedValue() throws {
                try syncing.apply([.aiUtterance(Applying.synced(arrivedAgain))], to: cache)

                #expect(Set(cache.all()) == [arrivedAgain, second])
            }
        }

        @Test("ほかの種類の変更は、キャッシュを変えないこと")
        func skipsOtherKinds() throws {
            try syncing.apply([.sentTextRemoval(sentTextId: first.sentTextId)], to: cache)

            #expect(cache.all().count == 2)
        }

        @Test("空にすると、返事がキャッシュから無くなること")
        func erases() throws {
            try syncing.erase(cache)

            #expect(cache.all().isEmpty)
        }
    }
}
