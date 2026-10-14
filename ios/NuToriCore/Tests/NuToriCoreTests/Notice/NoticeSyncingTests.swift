import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("知らせの同期の形")
struct NoticeSyncingTests {
    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = NoticeSyncing()
        let cache: MemoryKeyedRecordCache<Notice, UUID>
        let kept: Notice
        let removed: Notice

        init() throws {
            (cache, kept, removed) = try Self.appliedCache()
        }

        /// 知らせを2件当てたキャッシュ
        static func appliedCache() throws -> (
            cache: MemoryKeyedRecordCache<Notice, UUID>, kept: Notice, removed: Notice
        ) {
            let cache = MemoryKeyedRecordCache<Notice, UUID>(id: \.id)
            let kept = try Notice.missedWeightRecord(issuedAt: "2026-09-23T21:00:00+09:00")
            let removed = try Notice.missedWeightRecord(issuedAt: "2026-09-24T21:00:00+09:00")
            try NoticeSyncing().apply([kept, removed].map { .notice(synced($0)) }, to: cache)
            return (cache, kept, removed)
        }

        static func synced(_ notice: Notice) -> SyncedNotice {
            SyncedNotice(notice)
        }

        @Test("届いた知らせが今の値でキャッシュに入ること")
        func storesArrivedNotices() {
            #expect(Set(cache.all()) == [kept, removed])
        }

        @Suite("答えた知らせが届いたとき")
        struct RespondedArrived {
            let syncing = NoticeSyncing()
            let cache: MemoryKeyedRecordCache<Notice, UUID>
            let removed: Notice
            let responded: Notice

            init() throws {
                let applied = try Applying.appliedCache()
                let kept = applied.kept
                cache = applied.cache
                removed = applied.removed
                responded = kept.responded(
                    Notice.Response(
                        respondedAt: kept.issuedAt.addingTimeInterval(600),
                        timeZone: kept.timeZone))
            }

            @Test("キャッシュの知らせが答えを持つこと")
            func overwritesWithResponse() throws {
                try syncing.apply([.notice(Applying.synced(responded))], to: cache)

                #expect(Set(cache.all()) == [responded, removed])
            }
        }

        @Test("外す知らせが消え、キャッシュに無い知らせは読み飛ばすこと")
        func removesAndSkipsMissing() throws {
            try syncing.apply(
                [.noticeRemoval(noticeId: removed.id), .noticeRemoval(noticeId: UUID())],
                to: cache)

            #expect(cache.all() == [kept])
        }

        @Suite("対象の日付が読めない知らせが届いたとき")
        struct UnreadableTargetDayArrived {
            let syncing = NoticeSyncing()
            let cache: MemoryKeyedRecordCache<Notice, UUID>
            let kept: Notice
            let removed: Notice
            let unreadable: SyncedNotice

            init() throws {
                (cache, kept, removed) = try Applying.appliedCache()
                let notice = try Notice.missedWeightRecord(issuedAt: "2026-09-25T21:00:00+09:00")
                unreadable = SyncedNotice(
                    id: notice.id, noticeType: .missedWeightRecord(targetOn: "9月25日"),
                    issuedAt: notice.issuedAt, timeZone: notice.timeZone, response: nil)
            }

            @Test("キャッシュに入れないこと")
            func skipsNotice() throws {
                try syncing.apply([.notice(unreadable)], to: cache)

                #expect(Set(cache.all()) == [kept, removed])
            }
        }

        @Test("ほかの種類の変更は、キャッシュを変えないこと")
        func skipsOtherKinds() throws {
            try syncing.apply([.mealDeletion(mealId: kept.id)], to: cache)

            #expect(cache.all().count == 2)
        }

        @Test("空にすると、知らせがキャッシュから無くなること")
        func erases() throws {
            try syncing.erase(cache)

            #expect(cache.all().isEmpty)
        }
    }
}
