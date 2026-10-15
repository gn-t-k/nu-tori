import Foundation
import NuToriCore
import NuToriTestSupport
import Testing

/// 東京の 2026-10-14 9:00
@Suite("目標を立てる知らせの番")
struct GoalSetupNoticeKeeperTests {
    /// 種類の名前 goal-setup だけから作った UUID v5（名前空間は知らせの ID のもの）
    static let noticeId = UUID(uuidString: "CFCB73D9-A627-5553-B7E3-119003C5C5DC")!
    static let now = Date(timeIntervalSince1970: 1_791_936_000)

    static func keeper(store: any SyncBox & RecordCacheReading, now: Date = now) throws
        -> GoalSetupNoticeKeeper
    {
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        return GoalSetupNoticeKeeper(
            cache: store, timeZone: { tokyo }, now: { now },
            errorReporting: ErrorReportingSessionMock.ok())
    }

    @Suite("目標が無いまま初回の取得を終えたとき")
    struct NoGoalAfterInitialPull {
        let store: SyncBoxMock<RecordCacheMock>
        let keeper: GoalSetupNoticeKeeper

        init() throws {
            store = try .ok(state: .fixture(hasCompletedInitialPull: true))
            keeper = try GoalSetupNoticeKeeperTests.keeper(store: store)
        }

        @Test("種類だけから作る ID で、対象の日付を持たない答えていない知らせを、今出したものとしてキャッシュに置くこと")
        func issuesNotice() async throws {
            let enqueued = await keeper.issueIfNoGoal()

            #expect(enqueued)
            #expect(
                Array(store.cache.notices.values) == [
                    Notice(
                        id: GoalSetupNoticeKeeperTests.noticeId, kind: .goalSetup,
                        issuedAt: GoalSetupNoticeKeeperTests.now,
                        timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                        response: nil)
                ])
        }

        @Test("作る書き込みを1つ、送り待ちに先に積むこと")
        func enqueuesCreateBeforeCache() async throws {
            await keeper.issueIfNoGoal()

            #expect(
                try store.entries.map { try PendingNoticeWrite(entry: $0).write.noticeId } == [
                    GoalSetupNoticeKeeperTests.noticeId
                ])
            #expect(
                store.saves == [
                    .pending(added: 1, removed: 0), .cache(changes: 1, afterSequence: nil),
                ])
        }

        @Test("もう一度取りに行き終えても、知らせを二重に作らないこと")
        func doesNotIssueTwice() async {
            await keeper.issueIfNoGoal()
            let enqueuedAgain = await keeper.issueIfNoGoal()

            #expect(!enqueuedAgain)
            #expect(store.entries.count == 1)
            #expect(store.cache.notices.count == 1)
        }

        @Test("同時に2回呼ばれても、知らせを1つだけ作ること")
        func issuesOnceWhenCalledConcurrently() async {
            async let first = keeper.issueIfNoGoal()
            async let second = keeper.issueIfNoGoal()
            let enqueued = await [first, second]

            #expect(enqueued.count { $0 } == 1)
            #expect(store.entries.count == 1)
        }
    }

    @Suite("キャッシュに目標の記録があるとき")
    struct HasGoal {
        let store: SyncBoxMock<RecordCacheMock>
        let keeper: GoalSetupNoticeKeeper

        init() throws {
            store = try .ok(state: .fixture(hasCompletedInitialPull: true))
            store.cache.goalCache.upsert(try .maintaining())
            keeper = try GoalSetupNoticeKeeperTests.keeper(store: store)
        }

        @Test("知らせを作らないこと")
        func doesNotIssue() async {
            let enqueued = await keeper.issueIfNoGoal()

            #expect(!enqueued)
            #expect(store.entries.isEmpty)
            #expect(store.cache.notices.isEmpty)
        }
    }

    @Suite("初回の取得を終えていないとき")
    struct BeforeInitialPull {
        let store: SyncBoxMock<RecordCacheMock>
        let keeper: GoalSetupNoticeKeeper

        init() throws {
            store = try .ok(state: .fixture(hasCompletedInitialPull: false))
            keeper = try GoalSetupNoticeKeeperTests.keeper(store: store)
        }

        @Test("目標が届いていないだけかもしれないので、知らせを作らないこと")
        func doesNotIssue() async {
            let enqueued = await keeper.issueIfNoGoal()

            #expect(!enqueued)
            #expect(store.entries.isEmpty)
        }
    }

    @Suite("ほかの端末で答えた知らせが、キャッシュに届いているとき")
    struct AnsweredOnAnotherDevice {
        let store: SyncBoxMock<RecordCacheMock>
        let keeper: GoalSetupNoticeKeeper
        let answered: Notice

        init() throws {
            store = try .ok(state: .fixture(hasCompletedInitialPull: true))
            let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
            answered = Notice(
                id: GoalSetupNoticeKeeperTests.noticeId, kind: .goalSetup,
                issuedAt: GoalSetupNoticeKeeperTests.now.addingTimeInterval(-86_400),
                timeZone: tokyo,
                response: Notice.Response(
                    respondedAt: GoalSetupNoticeKeeperTests.now.addingTimeInterval(-3600),
                    timeZone: tokyo))
            store.cache.noticeCache.upsert(answered)
            keeper = try GoalSetupNoticeKeeperTests.keeper(store: store)
        }

        @Test("目標が無くても、知らせを作り直さないこと")
        func doesNotIssue() async {
            let enqueued = await keeper.issueIfNoGoal()

            #expect(!enqueued)
            #expect(Array(store.cache.notices.values) == [answered])
        }

        @Test("答えを送り待ちに足さず、先の答えを残すこと")
        func doesNotRespondAgain() async {
            let enqueued = await keeper.respondIfUnanswered()

            #expect(!enqueued)
            #expect(store.entries.isEmpty)
            #expect(Array(store.cache.notices.values) == [answered])
        }
    }

    @Suite("答えていない知らせがあるとき")
    struct Unanswered {
        let store: SyncBoxMock<RecordCacheMock>
        let issuedAt: Date
        let keeper: GoalSetupNoticeKeeper

        init() async throws {
            store = try .ok(state: .fixture(hasCompletedInitialPull: true))
            issuedAt = GoalSetupNoticeKeeperTests.now.addingTimeInterval(-600)
            await (try GoalSetupNoticeKeeperTests.keeper(store: store, now: issuedAt))
                .issueIfNoGoal()
            keeper = try GoalSetupNoticeKeeperTests.keeper(store: store)
        }

        @Test("目標が決まったときに、今答えた形にしてキャッシュに置くこと")
        func respondsNow() async throws {
            let enqueued = await keeper.respondIfUnanswered()

            let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
            #expect(enqueued)
            #expect(
                Array(store.cache.notices.values) == [
                    Notice(
                        id: GoalSetupNoticeKeeperTests.noticeId, kind: .goalSetup,
                        issuedAt: issuedAt, timeZone: tokyo,
                        response: Notice.Response(
                            respondedAt: GoalSetupNoticeKeeperTests.now, timeZone: tokyo))
                ])
        }

        @Test("作る書き込みのあとに、答える書き込みを1つ送り待ちに足すこと")
        func enqueuesRespondAfterCreate() async throws {
            await keeper.respondIfUnanswered()

            let writes = try store.entries.map { try PendingNoticeWrite(entry: $0).write }
            try #require(writes.count == 2)
            guard case .create = writes[0], case .respond(let noticeId, _) = writes[1] else {
                Issue.record("作る・答えるの順になっていない: \(writes)")
                return
            }
            #expect(noticeId == GoalSetupNoticeKeeperTests.noticeId)
        }

        @Test("目標を立て直して2回目に決まっても、答えを足すのは最初の1回だけであること")
        func respondsOnlyOnce() async {
            await keeper.respondIfUnanswered()
            let enqueuedAgain = await keeper.respondIfUnanswered()

            #expect(!enqueuedAgain)
            #expect(store.entries.count == 2)
        }

        @Test("同時に2回呼ばれても、答えを1つだけ足すこと")
        func respondsOnceWhenCalledConcurrently() async {
            async let first = keeper.respondIfUnanswered()
            async let second = keeper.respondIfUnanswered()
            let enqueued = await [first, second]

            #expect(enqueued.count { $0 } == 1)
            #expect(store.entries.count == 2)
        }
    }

    @Suite("知らせがキャッシュに無いまま、目標が決まったとき")
    struct NoNotice {
        let store: SyncBoxMock<RecordCacheMock>
        let keeper: GoalSetupNoticeKeeper

        init() throws {
            store = try .ok(state: .fixture(hasCompletedInitialPull: true))
            keeper = try GoalSetupNoticeKeeperTests.keeper(store: store)
        }

        @Test("答える書き込みを足さないこと")
        func doesNotRespond() async {
            let enqueued = await keeper.respondIfUnanswered()

            #expect(!enqueued)
            #expect(store.entries.isEmpty)
        }
    }

    @Suite("キャッシュを読めないとき")
    struct CacheUnreadable {
        let store: SyncBoxMock<RecordCacheMock>
        let errorReporting: ErrorReportingSessionMock
        let keeper: GoalSetupNoticeKeeper

        init() throws {
            store = .error(MissedWeightRecordWatchTests.SampleError())
            errorReporting = .ok()
            let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
            keeper = GoalSetupNoticeKeeper(
                cache: store, timeZone: { tokyo }, now: { GoalSetupNoticeKeeperTests.now },
                errorReporting: errorReporting)
        }

        @Test("知らせを作らず、失敗を報告すること")
        func reportsAndDoesNotIssue() async {
            let enqueued = await keeper.issueIfNoGoal()

            #expect(!enqueued)
            #expect(errorReporting.reported == [.cacheRead])
        }
    }
}
