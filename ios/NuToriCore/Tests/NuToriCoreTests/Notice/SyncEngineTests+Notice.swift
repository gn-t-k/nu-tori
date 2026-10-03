import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("知らせの同期")
    struct NoticeKind {
        @Suite("知らせを出したとき")
        struct Issuing {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine
            let notice: Notice

            init() throws {
                store = try .ok()
                engine = .fixture(store: store, transport: .sync())
                notice = try Notice.fixture()
            }

            @Test("送り待ちに知らせの種類の名前で入れてから、キャッシュに答えていない知らせを置くこと")
            func enqueuesThenCaches() async throws {
                try await engine.issueNotice(notice)

                #expect(store.entries.map(\.kind) == [.notice])
                #expect(
                    store.saves == [
                        .pending(added: 1, removed: 0), .cache(changes: 1, afterSequence: nil),
                    ])
                #expect(store.cache.notices[notice.id] == notice)
            }
        }

        @Suite("知らせを出して送ったとき")
        struct IssuingThenSending {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine
            let notice: Notice

            init() async throws {
                store = try .ok()
                transport = .sync()
                engine = .fixture(store: store, transport: transport)
                notice = try Notice.fixture()
                try await engine.issueNotice(notice)
            }

            @Test("種類・出した時刻・タイムゾーン・対象の日付を、作る書き込みで送ること")
            func sendsCreateNotice() async throws {
                _ = try await engine.sync()

                #expect(
                    try #require(transport.pushBodies.first).writes.map(\.type) == [
                        "create_notice"
                    ])
                guard
                    case .createNotice(_, let sent) = try #require(
                        transport.pushBodies.first?.writes.first)
                else {
                    Issue.record("作る書き込みでない")
                    return
                }
                #expect(
                    sent
                        == SentWritesBody.Notice(
                            id: notice.id.uuidString,
                            noticeType: "missed_weight_record",
                            issuedAt: 1_790_028_900_000,
                            timeZone: "Asia/Tokyo",
                            targetOn: "2026-09-22"
                        ))
                #expect(store.entries.isEmpty)
            }
        }

        @Suite("出した知らせに答えたとき")
        struct Responding {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine
            let notice: Notice

            init() async throws {
                store = try .ok()
                transport = .sync()
                engine = .fixture(store: store, transport: transport)
                notice = try Notice.fixture()
                try await engine.issueNotice(notice)
            }

            @Test("キャッシュの知らせを、今の時刻とタイムゾーンで答えた形にすること")
            func cachesRespondedNotice() async throws {
                try await engine.respondToNotice(id: notice.id)

                #expect(
                    store.cache.notices[notice.id]?.response
                        == Notice.Response(
                            respondedAt: SyncEngine.fixtureNow,
                            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))))
                #expect(store.entries.map(\.kind) == [.notice, .notice])
            }

            @Test("作る書き込みのあとに、知らせの ID と答えた時刻・タイムゾーンを添えた答える書き込みを送ること")
            func sendsRespondAfterCreate() async throws {
                try await engine.respondToNotice(id: notice.id)

                _ = try await engine.sync()

                let writes = try #require(transport.pushBodies.first).writes
                #expect(writes.map(\.type) == ["create_notice", "respond_notice"])
                #expect(
                    writes.last
                        == .respondNotice(
                            id: try #require(writes.last).id, noticeId: notice.id.uuidString,
                            .init(respondedAt: 1_767_225_600_000, timeZone: "Asia/Tokyo")))
            }

            @Test("すでに答えた知らせには、答える書き込みを足さないこと")
            func ignoresSecondResponse() async throws {
                try await engine.respondToNotice(id: notice.id)

                try await engine.respondToNotice(id: notice.id)

                #expect(store.entries.map(\.kind) == [.notice, .notice])
            }
        }

        @Suite("キャッシュに無い知らせに答えようとしたとき")
        struct RespondingToUnknown {
            @Test("知らない記録として投げ、送り待ちに入れず、キャッシュを読めなかった失敗として1回送ること")
            func throwsUnknownRecord() async throws {
                let store = try SyncBoxMock.ok()
                let errorReporting = ErrorReportingSessionMock.ok()
                let engine = SyncEngine.fixture(
                    store: store, transport: .sync(), errorReporting: errorReporting)
                let noticeId = UUID()

                await #expect(throws: SyncEngine.UnknownRecordError(recordId: noticeId)) {
                    try await engine.respondToNotice(id: noticeId)
                }
                #expect(store.entries.isEmpty)
                #expect(errorReporting.reported == [.cacheRead])
            }
        }

        @Suite("キャッシュを読めないときに知らせに答えようとしたとき")
        struct RespondingWithUnreadableCache {
            struct SampleError: Error {}

            @Test("投げ、キャッシュを読めなかった失敗として1回送ること")
            func reportsReadFailure() async {
                let errorReporting = ErrorReportingSessionMock.ok()
                let engine = SyncEngine.fixture(
                    store: .error(SampleError()), transport: .sync(),
                    errorReporting: errorReporting)

                await #expect(throws: SampleError.self) {
                    try await engine.respondToNotice(id: UUID())
                }
                #expect(errorReporting.reported == [.cacheRead])
            }
        }

        @Suite("サーバーが答える書き込みを受け付けず、答えていない知らせを今の値に添えたとき")
        struct RejectedWithValue {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine
            let notice: Notice

            init() async throws {
                notice = try Notice.fixture()
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(
                        rejectedWriteIndexes: [1], currents: [1: .unansweredNotice(notice)]))
                try await engine.issueNotice(notice)
                try await engine.respondToNotice(id: notice.id)
            }

            @Test("キャッシュの知らせをサーバーの今の値（答えていない形）に戻し、受け付けなかった行は出さないこと")
            func revertsToServerValueWithoutLine() async throws {
                let result = try await engine.sync()

                #expect(store.cache.notices[notice.id] == notice)
                #expect(result.rejectedWrites.isEmpty)
                #expect(store.entries.isEmpty)
            }
        }

        @Suite("サーバーが作る書き込みを受け付けず、サーバーに知らせが無いとき")
        struct RejectedWithoutValue {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine
            let notice: Notice

            init() async throws {
                notice = try Notice.fixture()
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(rejectedWriteIndexes: [0], currents: [0: .absent]))
                try await engine.issueNotice(notice)
            }

            @Test("知らせをキャッシュから外し、受け付けなかった行は出さないこと")
            func removesNoticeWithoutLine() async throws {
                let result = try await engine.sync()

                #expect(store.cache.notices[notice.id] == nil)
                #expect(result.rejectedWrites.isEmpty)
            }
        }

        @Suite("知らせの変更を取りに行ったとき")
        struct Pulling {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine
            let noticeId: UUID

            init() throws {
                noticeId = try #require(UUID(uuidString: "00000000-0000-5000-8000-0000000000a1"))
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          {"sequence":1,"kind":"notice","recordId":"\(noticeId.uuidString)",
                           "record":{"id":"\(noticeId.uuidString)","noticeType":"missed_weight_record",
                             "issuedAt":1790028900000,"timeZone":"Asia/Tokyo","targetOn":"2026-09-22",
                             "response":{"respondedAt":1790029800000,"timeZone":"America/Los_Angeles"}}}
                        ],"hasMore":false,"nextAfterSequence":1,"startedOn":null}
                        """
                    ]))
            }

            @Test("ほかの端末で答えた知らせを、答えた形でキャッシュに当てること")
            func appliesRespondedNotice() async throws {
                _ = try await engine.sync()

                #expect(
                    store.cache.notices[noticeId]
                        == Notice(
                            id: noticeId,
                            kind: .missedWeightRecord,
                            issuedAt: Date(timeIntervalSince1970: 1_790_028_900),
                            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                            targetDay: CalendarDay(year: 2026, month: 9, day: 22),
                            response: Notice.Response(
                                respondedAt: Date(timeIntervalSince1970: 1_790_029_800),
                                timeZone: try #require(
                                    TimeZone(identifier: "America/Los_Angeles")))
                        ))
            }
        }

        @Suite("読める種類に知らせ・いつもの時刻・体重の傾向が増えた版で、更新して最初に開いたとき")
        struct AfterUpdateAddingNoticeKinds {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() throws {
                store = try .ok(
                    state: .fixture(
                        afterSequence: 120, hasCompletedInitialPull: true,
                        readableKinds: [
                            .accountSettings, .dish, .ingredient, .meal, .mealEstimationStatus,
                            .weightRecord,
                        ]))
                transport = .sync()
                engine = .fixture(
                    store: store, transport: transport,
                    readableKinds: RecordKindRegistry<RecordCacheMock>.ok().names)
            }

            @Test("通し番号を 0 に戻して全部取り直し、読める種類に知らせ・いつもの時刻・体重の傾向を足すこと")
            func pullsEverythingAgain() async throws {
                _ = try await engine.sync()

                #expect(try transport.pullQueries.first?["afterSequence"] == "0")
                #expect(
                    store.state?.readableKinds
                        == [
                            .accountSettings, .dish, .ingredient, .meal, .mealEstimationStatus,
                            .notice, .usualWeighingTime, .weightRecord, .weightTrend,
                        ])
            }
        }
    }
}

extension Notice {
    /// 2026-09-22 7:15（東京）に出した、その日の体重の記録忘れの知らせ
    fileprivate static func fixture() throws -> Notice {
        Notice(
            id: try #require(UUID(uuidString: "00000000-0000-5000-8000-0000000000a1")),
            kind: .missedWeightRecord,
            issuedAt: Date(timeIntervalSince1970: 1_790_028_900),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
            targetDay: CalendarDay(year: 2026, month: 9, day: 22),
            response: nil
        )
    }
}
