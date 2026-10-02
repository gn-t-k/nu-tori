import Foundation
import NuToriAPI
import NuToriCore
import Testing

@testable import NuTori

@Suite("知らせの種類")
@MainActor
struct NoticeRecordKindTests {
    let store: SwiftDataSyncStore
    let noticeId: UUID
    let tokyo: TimeZone

    init() throws {
        store = try SwiftDataSyncStore(inMemory: true)
        noticeId = UUID(uuidString: "00000000-0000-5000-8000-0000000000a1")!
        tokyo = TimeZone(identifier: "Asia/Tokyo")!
    }

    func synced(response: SyncedNotice.Response?) -> SyncedNotice {
        SyncedNotice(
            id: noticeId, noticeType: .missedWeightRecord,
            issuedAt: Date(timeIntervalSince1970: 1_790_028_900), timeZone: tokyo,
            targetOn: "2026-09-22", response: response)
    }

    @Test("答えていない知らせのあとに答えた知らせが届くと、答えた形でキャッシュに持つこと")
    func storesRespondedNotice() async throws {
        let response = SyncedNotice.Response(
            respondedAt: Date(timeIntervalSince1970: 1_790_029_800), timeZone: tokyo)

        try await store.apply(
            SyncBoxResult(kindChanges: [
                KindChanges(kind: .notice, changes: [.notice(synced(response: nil))])
            ]))
        try await store.apply(
            SyncBoxResult(kindChanges: [
                KindChanges(kind: .notice, changes: [.notice(synced(response: response))])
            ]))

        #expect(
            try await store.notices() == [
                Notice(
                    id: noticeId, kind: .missedWeightRecord,
                    issuedAt: Date(timeIntervalSince1970: 1_790_028_900), timeZone: tokyo,
                    targetDay: CalendarDay(year: 2026, month: 9, day: 22),
                    response: Notice.Response(
                        respondedAt: Date(timeIntervalSince1970: 1_790_029_800), timeZone: tokyo))
            ])
    }

    @Test("外す変更で、知らせをキャッシュから消すこと")
    func removesNotice() async throws {
        try await store.apply(
            SyncBoxResult(kindChanges: [
                KindChanges(kind: .notice, changes: [.notice(synced(response: nil))])
            ]))

        try await store.apply(
            SyncBoxResult(kindChanges: [
                KindChanges(kind: .notice, changes: [.noticeRemoval(noticeId: noticeId)])
            ]))

        #expect(try await store.notices().isEmpty)
    }
}
