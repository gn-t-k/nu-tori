import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("知らせの同期")
    struct NoticeKind {
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
                try await store.issue(notice)
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

        @Suite("出した知らせに答えて送ったとき")
        struct RespondingThenSending {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine
            let notice: Notice

            init() async throws {
                store = try .ok()
                transport = .sync()
                engine = .fixture(store: store, transport: transport)
                notice = try Notice.fixture()
                try await store.issue(notice)
                try await store.respond(to: notice)
            }

            @Test("作る書き込みのあとに、知らせの ID と答えた時刻・タイムゾーンを添えた答える書き込みを送ること")
            func sendsRespondAfterCreate() async throws {
                _ = try await engine.sync()

                let writes = try #require(transport.pushBodies.first).writes
                #expect(writes.map(\.type) == ["create_notice", "respond_notice"])
                #expect(
                    writes.last
                        == .respondNotice(
                            id: try #require(writes.last).id, noticeId: notice.id.uuidString,
                            .init(respondedAt: 1_767_225_600_000, timeZone: "Asia/Tokyo")))
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
                try await store.issue(notice)
                try await store.respond(to: notice)
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
                try await store.issue(notice)
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

extension SyncBoxMock where Cache == RecordCacheMock {
    /// 知らせを出した形にする。出すかの判断は、記録忘れの見張りのテストで確かめる
    fileprivate func issue(_ notice: Notice) async throws {
        try await apply(
            NoticeSyncing().issuing(
                notice,
                enqueuing: Pending(enqueuedAt: SyncEngine.fixtureNow, write: .create(notice))))
    }

    /// 知らせに、今（東京）答えた形にする
    fileprivate func respond(to notice: Notice) async throws {
        let response = Notice.Response(
            respondedAt: SyncEngine.fixtureNow,
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")))
        try await apply(
            NoticeSyncing().responding(
                to: notice, with: response,
                enqueuing: Pending(
                    enqueuedAt: SyncEngine.fixtureNow,
                    write: .respond(noticeId: notice.id, response: response))))
    }
}
