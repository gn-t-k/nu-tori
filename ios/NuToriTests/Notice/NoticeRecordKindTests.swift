import Foundation
import NuToriAPI
import NuToriCore
import Testing

@testable import NuTori

@Suite("知らせの種類")
struct NoticeRecordKindTests {
    static func noticeId() throws -> UUID {
        try #require(UUID(uuidString: "00000000-0000-5000-8000-0000000000a1"))
    }

    static func tokyo() throws -> TimeZone {
        try #require(TimeZone(identifier: "Asia/Tokyo"))
    }

    static func synced(response: SyncedNotice.Response?) throws -> SyncedNotice {
        SyncedNotice(
            id: try noticeId(), noticeType: .missedWeightRecord,
            issuedAt: Date(timeIntervalSince1970: 1_790_028_900), timeZone: try tokyo(),
            targetOn: "2026-09-22", response: response)
    }

    @Suite("答えていない知らせがキャッシュにあり、答えた知らせが届いたとき")
    @MainActor
    struct Responded {
        let store: SwiftDataSyncStore
        let responded: SyncedNotice
        let expected: Notice

        init() async throws {
            store = try SwiftDataSyncStore(inMemory: true)
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(
                        kind: .notice,
                        changes: [.notice(try NoticeRecordKindTests.synced(response: nil))])
                ]))
            let tokyo = try NoticeRecordKindTests.tokyo()
            responded = try NoticeRecordKindTests.synced(
                response: SyncedNotice.Response(
                    respondedAt: Date(timeIntervalSince1970: 1_790_029_800), timeZone: tokyo))
            expected = Notice(
                id: try NoticeRecordKindTests.noticeId(), kind: .missedWeightRecord,
                issuedAt: Date(timeIntervalSince1970: 1_790_028_900), timeZone: tokyo,
                targetDay: CalendarDay(year: 2026, month: 9, day: 22),
                response: Notice.Response(
                    respondedAt: Date(timeIntervalSince1970: 1_790_029_800), timeZone: tokyo))
        }

        @Test("答えた形でキャッシュに持つこと")
        func storesRespondedNotice() async throws {
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(kind: .notice, changes: [.notice(responded)])
                ]))

            #expect(try await store.notices() == [expected])
        }
    }

    @Suite("知らせがキャッシュにあり、外す変更が届いたとき")
    @MainActor
    struct Removed {
        let store: SwiftDataSyncStore
        let noticeId: UUID

        init() async throws {
            store = try SwiftDataSyncStore(inMemory: true)
            noticeId = try NoticeRecordKindTests.noticeId()
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(
                        kind: .notice,
                        changes: [.notice(try NoticeRecordKindTests.synced(response: nil))])
                ]))
        }

        @Test("知らせをキャッシュから消すこと")
        func removesNotice() async throws {
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(kind: .notice, changes: [.noticeRemoval(noticeId: noticeId)])
                ]))

            #expect(try await store.notices().isEmpty)
        }
    }
}
