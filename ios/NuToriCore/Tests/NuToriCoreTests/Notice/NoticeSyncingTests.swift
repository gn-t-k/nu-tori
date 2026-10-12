import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("知らせの同期の形")
struct NoticeSyncingTests {
    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = NoticeSyncing()
        let cache = MemoryKeyedRecordCache<Notice, UUID>(id: \.id)
        let kept: Notice
        let removed: Notice

        init() throws {
            kept = try .missedWeightRecord(issuedAt: "2026-09-23T21:00:00+09:00")
            removed = try .missedWeightRecord(issuedAt: "2026-09-24T21:00:00+09:00")
            try syncing.apply([kept, removed].map { .notice(Self.synced($0)) }, to: cache)
        }

        static func synced(_ notice: Notice, targetOn: String? = nil) -> SyncedNotice {
            SyncedNotice(
                id: notice.id, noticeType: .missedWeightRecord, issuedAt: notice.issuedAt,
                timeZone: notice.timeZone, targetOn: targetOn ?? notice.targetDay.yearMonthDay,
                response: notice.response.map {
                    .init(respondedAt: $0.respondedAt, timeZone: $0.timeZone)
                })
        }

        @Test("届いた知らせが今の値でキャッシュに入ること")
        func storesArrivedNotices() {
            #expect(Set(cache.all()) == [kept, removed])
        }

        @Test("答えた知らせが届いたら、キャッシュの知らせが答えを持つこと")
        func overwritesWithResponse() throws {
            let responded = Notice(
                id: kept.id, kind: kept.kind, issuedAt: kept.issuedAt, timeZone: kept.timeZone,
                targetDay: kept.targetDay,
                response: Notice.Response(
                    respondedAt: kept.issuedAt.addingTimeInterval(600), timeZone: kept.timeZone))

            try syncing.apply([.notice(Self.synced(responded))], to: cache)

            #expect(Set(cache.all()) == [responded, removed])
        }

        @Test("外す知らせが消え、キャッシュに無い知らせは読み飛ばすこと")
        func removesAndSkipsMissing() throws {
            try syncing.apply(
                [.noticeRemoval(noticeId: removed.id), .noticeRemoval(noticeId: UUID())],
                to: cache)

            #expect(cache.all() == [kept])
        }

        @Test("対象の日付が読めない知らせは、キャッシュに入れないこと")
        func skipsUnreadableTargetDay() throws {
            let unreadable = try Notice.missedWeightRecord(issuedAt: "2026-09-25T21:00:00+09:00")

            try syncing.apply([.notice(Self.synced(unreadable, targetOn: "9月25日"))], to: cache)

            #expect(Set(cache.all()) == [kept, removed])
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
