import Foundation
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    /// 今は 2026-01-01 9:00（東京）。いつもの時刻が無いので、通知の時刻は 8:00
    @Suite("体重の知らせを出す・答える")
    struct MissedWeightRecordNotices {
        static let today = CalendarDay(year: 2026, month: 1, day: 1)

        @Suite("初回の取得を終え、今日の体重記録が無く、通知の時刻を過ぎたとき")
        struct DueToday {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() throws {
                store = try .ok(state: .fixture(hasCompletedInitialPull: true))
                engine = .fixture(store: store, transport: .sync())
            }

            @Test("今日の知らせを、通知の時刻に出したものとして作り、送り待ちに入れること")
            func issuesTodayNotice() async throws {
                let enqueued = try await engine.issueOrRespondToMissedWeightRecordNotices()

                let noticeId = Notice.id(
                    kind: .missedWeightRecord, targetDay: MissedWeightRecordNotices.today)
                #expect(enqueued)
                #expect(store.entries.map(\.kind) == [.notice])
                #expect(
                    store.cache.notices[noticeId]?.issuedAt
                        == SyncEngine.fixtureNow.addingTimeInterval(-60 * 60))
            }

            @Test("2回呼んでも、知らせを1つだけ作ること")
            func issuesOnce() async throws {
                try await engine.issueOrRespondToMissedWeightRecordNotices()

                let enqueued = try await engine.issueOrRespondToMissedWeightRecordNotices()

                #expect(!enqueued)
                #expect(store.entries.map(\.kind) == [.notice])
            }
        }

        @Suite("初回の取得を終えていないとき")
        struct BeforeInitialPull {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() throws {
                store = try .ok(state: .fixture(hasCompletedInitialPull: false))
                engine = .fixture(store: store, transport: .sync())
            }

            @Test("記録がそろっていないので、知らせを出さないこと")
            func issuesNothing() async throws {
                let enqueued = try await engine.issueOrRespondToMissedWeightRecordNotices()

                #expect(!enqueued)
                #expect(store.entries.isEmpty)
                #expect(store.cache.notices.isEmpty)
            }
        }

        @Suite("答えていない今日の知らせがあり、今日の体重記録がキャッシュに入ったとき")
        struct RecordedAfterNotice {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine
            let noticeId: UUID

            init() async throws {
                store = try .ok(state: .fixture(hasCompletedInitialPull: true))
                engine = .fixture(store: store, transport: .sync())
                try await engine.issueOrRespondToMissedWeightRecordNotices()
                noticeId = Notice.id(
                    kind: .missedWeightRecord, targetDay: MissedWeightRecordNotices.today)
                store.cache.upsert(
                    try WeightRecord.imported(
                        72.4, at: "2026-01-01T08:50:00+09:00", in: "Asia/Tokyo"))
            }

            @Test("知らせを答えた形にし、答える書き込みを送り待ちに入れること")
            func respondsToNotice() async throws {
                let enqueued = try await engine.issueOrRespondToMissedWeightRecordNotices()

                #expect(enqueued)
                #expect(store.entries.map(\.kind) == [.notice, .notice])
                #expect(store.cache.notices[noticeId]?.response != nil)
            }
        }
    }
}
