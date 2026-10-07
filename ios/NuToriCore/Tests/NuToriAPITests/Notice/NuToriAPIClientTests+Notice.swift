import Foundation
import NuToriTestSupport
import Testing

@testable import NuToriAPI

extension NuToriAPIClientTests {
    @Suite("知らせ・いつもの時刻・体重の傾向の同期")
    struct NoticeSync {
        static let noticeId = "00000000-0000-5000-8000-0000000000a1"
        static let usualWeighingTimeId = "00000000-0000-4000-8000-0000000000b1"

        @Suite("知らせを作る書き込みと答える書き込みを送るとき")
        struct PushingNoticeWrites {
            let createWriteId: UUID
            let respondWriteId: UUID
            let transport: ClientTransportMock
            let client: NuToriAPIClient
            let writes: [SyncWrite]

            init() throws {
                createWriteId = try #require(
                    UUID(uuidString: "00000000-0000-4000-8000-0000000000a1"))
                respondWriteId = try #require(
                    UUID(uuidString: "00000000-0000-4000-8000-0000000000a2"))
                let noticeId = try #require(UUID(uuidString: NoticeSync.noticeId))
                let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
                let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
                writes = [
                    .createNotice(
                        writeId: createWriteId,
                        notice: NewNotice(
                            id: noticeId,
                            noticeType: .missedWeightRecord,
                            issuedAt: Date(timeIntervalSince1970: 1_767_225_600.123),
                            timeZone: tokyo,
                            targetOn: "2026-01-01"
                        )),
                    .respondNotice(
                        writeId: respondWriteId,
                        noticeId: noticeId,
                        response: SyncedNotice.Response(
                            respondedAt: Date(timeIntervalSince1970: 1_767_229_200),
                            timeZone: losAngeles)),
                ]
                transport = .ok(
                    json: """
                        {"results":[
                          {"writeId":"\(createWriteId.canonicalString)","result":"rejected","rejectionReason":"invalid_notice_type"},
                          {"writeId":"\(respondWriteId.canonicalString)","result":"rejected","rejectionReason":"invalid_target_on"}
                        ]}
                        """
                )
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: transport,
                    appBuildGate: .sample,
                    sessionToken: { "session-1" }
                )
            }

            @Test("作る書き込みは種類・出した時刻・タイムゾーン・対象の日付を、答える書き込みは知らせの ID と答えた時刻・タイムゾーンを送ること")
            func sendsNoticeWrites() async throws {
                _ = try await client.pushSyncWrites(
                    writes, isFinalBatch: true, clientState: .fixture())

                let sent = try #require(transport.requests.first)
                #expect(
                    try PushSyncWritesPayload(sentBody: sent.body).writes == [
                        .createNotice(
                            .init(
                                id: "00000000-0000-4000-8000-0000000000a1",
                                _type: .createNotice,
                                notice: .init(
                                    id: NoticeSync.noticeId,
                                    noticeType: "missed_weight_record",
                                    issuedAt: 1_767_225_600_123,
                                    timeZone: "Asia/Tokyo",
                                    targetOn: "2026-01-01"
                                ))
                        ),
                        .respondNotice(
                            .init(
                                id: "00000000-0000-4000-8000-0000000000a2",
                                _type: .respondNotice,
                                noticeId: NoticeSync.noticeId,
                                response: .init(
                                    respondedAt: 1_767_229_200_000,
                                    timeZone: "America/Los_Angeles"))
                        ),
                    ])
            }

            @Test("知らせで足した受け付けなかった理由を読むこと")
            func readsNoticeRejectionReasons() async throws {
                let result = try await client.pushSyncWrites(
                    writes, isFinalBatch: true, clientState: .fixture())

                guard case .pushed(let results) = result else {
                    Issue.record("結果が返っていない: \(result)")
                    return
                }
                #expect(
                    results.map(\.outcome) == [
                        .rejected(.invalidNoticeType), .rejected(.invalidTargetOn),
                    ])
            }
        }

        @Suite("知らせ・いつもの時刻・体重の傾向の変更を取りに行ったとき")
        struct PullingChanges {
            let client: NuToriAPIClient

            init() {
                let noticeId = NoticeSync.noticeId
                let timeId = NoticeSync.usualWeighingTimeId
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(
                        json: """
                            {"changes":[
                              {"sequence":1,"kind":"notice","recordId":"\(noticeId)",
                               "record":{"id":"\(noticeId)","noticeType":"missed_weight_record",
                                 "issuedAt":1767225600123,"timeZone":"Asia/Tokyo","targetOn":"2026-01-01"}},
                              {"sequence":2,"kind":"notice","recordId":"\(noticeId)",
                               "record":{"id":"\(noticeId)","noticeType":"missed_weight_record",
                                 "issuedAt":1767225600123,"timeZone":"Asia/Tokyo","targetOn":"2026-01-01",
                                 "response":{"respondedAt":1767229200000,"timeZone":"America/Los_Angeles"}}},
                              {"sequence":3,"kind":"notice","recordId":"\(noticeId)",
                               "record":{"id":"\(noticeId)","noticeType":"goal_reached",
                                 "issuedAt":1767225600123,"timeZone":"Asia/Tokyo","targetOn":"2026-01-01"}},
                              {"sequence":4,"kind":"usual_weighing_time","recordId":"\(timeId)",
                               "record":{"minuteOfDay":435}},
                              {"sequence":5,"kind":"weight_trend","recordId":"weight_trend",
                               "record":{"days":[{"calendarDay":"2026-01-01","trendKg":72.4},
                                 {"calendarDay":"2026-01-02","trendKg":72.3125}]}},
                              {"sequence":6,"kind":"weight_trend_absence","recordId":"weight_trend","record":{}}
                            ],"hasMore":false,"nextAfterSequence":6,"startedOn":"2026-09-29"}
                            """
                    ),
                    appBuildGate: .sample,
                    sessionToken: { "session-1" }
                )
            }

            @Test("知らせ（答えを含む）・いつもの時刻・体重の傾向・傾向が無くなった印を解き、知らない種類の知らせは読み飛ばせる形で返すこと")
            func returnsChanges() async throws {
                let result = try await client.pullSyncChanges(
                    afterSequence: 0, clientState: .fixture())

                let noticeId = try #require(UUID(uuidString: NoticeSync.noticeId))
                let timeId = try #require(UUID(uuidString: NoticeSync.usualWeighingTimeId))
                let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
                let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
                func notice(response: SyncedNotice.Response?) -> SyncChange {
                    .notice(
                        SyncedNotice(
                            id: noticeId, noticeType: .missedWeightRecord,
                            issuedAt: Date(timeIntervalSince1970: 1_767_225_600.123),
                            timeZone: tokyo, targetOn: "2026-01-01", response: response))
                }
                #expect(
                    result
                        == .pulled(
                            SyncChangesPage(
                                changes: [
                                    notice(response: nil),
                                    notice(
                                        response: SyncedNotice.Response(
                                            respondedAt: Date(timeIntervalSince1970: 1_767_229_200),
                                            timeZone: losAngeles)),
                                    .unknown(kind: "notice"),
                                    .usualWeighingTime(
                                        SyncedUsualWeighingTime(id: timeId, minuteOfDay: 435)),
                                    .weightTrend(
                                        SyncedWeightTrend(days: [
                                            .init(calendarDay: "2026-01-01", trendKilograms: 72.4),
                                            .init(
                                                calendarDay: "2026-01-02", trendKilograms: 72.3125),
                                        ])),
                                    .weightTrendAbsence,
                                ],
                                hasMore: false,
                                nextAfterSequence: 6,
                                startedOn: "2026-09-29"
                            )))
            }
        }
    }
}
