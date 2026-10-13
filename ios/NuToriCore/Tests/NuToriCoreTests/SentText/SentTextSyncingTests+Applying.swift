import Foundation
import NuToriAPI
import NuToriCore
import Testing

extension SentTextSyncingTests {
    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = SentTextSyncing()
        let cache: MemoryKeyedRecordCache<SentText, UUID>
        let kept: SentText
        let removed: SentText

        init() throws {
            (cache, kept, removed) = try Self.appliedCache()
        }

        /// 送った文章を2件当てたキャッシュ
        static func appliedCache() throws -> (
            cache: MemoryKeyedRecordCache<SentText, UUID>, kept: SentText, removed: SentText
        ) {
            let cache = MemoryKeyedRecordCache<SentText, UUID>(id: \.id)
            let kept = try SentText.fixture("朝はパン", sentAt: "2026-09-24T08:10:00+09:00")
            let removed = try SentText.fixture("昼はそば", sentAt: "2026-09-24T12:10:00+09:00")
            try SentTextSyncing().apply([kept, removed].map { .sentText(synced($0)) }, to: cache)
            return (cache, kept, removed)
        }

        static func synced(_ sentText: SentText) -> SyncedSentText {
            SyncedSentText(
                id: sentText.id, body: sentText.body, sentAt: sentText.sentAt,
                timeZone: sentText.timeZone)
        }

        @Test("届いた送った文章が今の値でキャッシュに入ること")
        func storesArrivedSentTexts() {
            #expect(Set(cache.all()) == [kept, removed])
        }

        @Suite("同じ送った文章が届き直したとき")
        struct ArrivedAgain {
            let syncing = SentTextSyncing()
            let cache: MemoryKeyedRecordCache<SentText, UUID>
            let removed: SentText
            let arrivedAgain: SentText

            init() throws {
                let applied = try Applying.appliedCache()
                cache = applied.cache
                removed = applied.removed
                arrivedAgain = try SentText.fixture(
                    "朝はごはん", sentAt: "2026-09-24T08:10:00+09:00", id: applied.kept.id)
            }

            @Test("キャッシュの文章をその値にそろえること")
            func overwritesWithArrivedValue() throws {
                try syncing.apply([.sentText(Applying.synced(arrivedAgain))], to: cache)

                #expect(Set(cache.all()) == [arrivedAgain, removed])
            }
        }

        @Test("外す送った文章が消え、キャッシュに無い文章は読み飛ばすこと")
        func removesAndSkipsMissing() throws {
            try syncing.apply(
                [.sentTextRemoval(sentTextId: removed.id), .sentTextRemoval(sentTextId: UUID())],
                to: cache)

            #expect(cache.all() == [kept])
        }

        @Test("同じ送った文章の今の値と外す変更が一緒に届いたら、消えていること")
        func removalWinsOverValueInSameChanges() throws {
            try syncing.apply(
                [.sentTextRemoval(sentTextId: kept.id), .sentText(Self.synced(kept))], to: cache)

            #expect(cache.all() == [removed])
        }

        @Test("ほかの種類の変更は、キャッシュを変えないこと")
        func skipsOtherKinds() throws {
            try syncing.apply([.mealDeletion(mealId: kept.id)], to: cache)

            #expect(cache.all().count == 2)
        }

        @Test("空にすると、送った文章がキャッシュから無くなること")
        func erases() throws {
            try syncing.erase(cache)

            #expect(cache.all().isEmpty)
        }
    }
}
