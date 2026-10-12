import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("返事の同期の形")
struct AiUtteranceSyncingTests {
    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = AiUtteranceSyncing()
        let cache = MemoryKeyedRecordCache<AiUtterance, UUID>(id: \.id)
        /// 応える送った文章は届いていない
        let first = AiUtterance(id: UUID(), body: "よく食べました", sentTextId: UUID(), mealIds: [])
        let second = AiUtterance(
            id: UUID(), body: "昼はこちらです", sentTextId: UUID(), mealIds: [UUID(), UUID()])

        init() throws {
            try syncing.apply([first, second].map { .aiUtterance(Self.synced($0)) }, to: cache)
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

        @Test("同じ返事が届き直したら、キャッシュの返事をその値にそろえること")
        func overwritesArrivedAgain() throws {
            let arrivedAgain = AiUtterance(
                id: first.id, body: "よく食べましたね", sentTextId: first.sentTextId,
                mealIds: [UUID()])

            try syncing.apply([.aiUtterance(Self.synced(arrivedAgain))], to: cache)

            #expect(Set(cache.all()) == [arrivedAgain, second])
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
