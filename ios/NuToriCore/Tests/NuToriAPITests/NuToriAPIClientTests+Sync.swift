import Foundation
import HTTPTypes
import Testing

@testable import NuToriAPI

extension NuToriAPIClientTests {
    @Suite("送り待ちを送る")
    struct PushSyncWrites {
        static let createWriteId = UUID(uuidString: "00000000-0000-4000-8000-0000000000a1")!
        static let updateWriteId = UUID(uuidString: "00000000-0000-4000-8000-0000000000a2")!

        @Suite("サーバーが書き込みごとの結果を返したとき")
        struct Pushed {
            let transport: ClientTransportMock
            let client: NuToriAPIClient
            let clientState: SyncClientState
            let writes: [SyncWrite]

            init() {
                clientState = .fixture()
                writes = [
                    .createWeightRecord(
                        writeId: PushSyncWrites.createWriteId, record: .fixture()),
                    .updateWeightRecord(
                        writeId: PushSyncWrites.updateWriteId, correction: .fixture()),
                ]
                transport = .ok(
                    json: """
                        {"results":[
                          {"writeId":"\(PushSyncWrites.createWriteId.uuidString)","result":"applied"},
                          {"writeId":"\(PushSyncWrites.updateWriteId.uuidString)","result":"rejected","rejectionReason":"out_of_range"}
                        ]}
                        """
                )
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: transport,
                    sessionToken: { "session-1" }
                )
            }

            @Test("書き込みごとの結果を、送った順に返すこと")
            func returnsResultsPerWrite() async throws {
                let result = try await client.pushSyncWrites(
                    writes, isFinalBatch: true, clientState: clientState)

                #expect(
                    result
                        == .pushed([
                            SyncWriteResult(
                                writeId: PushSyncWrites.createWriteId, outcome: .applied),
                            SyncWriteResult(
                                writeId: PushSyncWrites.updateWriteId,
                                outcome: .rejected(.outOfRange)),
                        ])
                )
            }

            @Test("書き込みと端末の状態と送り切った印を、セッションのトークンつきで POST /v1/sync/writes に送ること")
            func sendsWrites() async throws {
                _ = try await client.pushSyncWrites(
                    writes, isFinalBatch: true, clientState: clientState)

                let sent = try #require(transport.requests.first)
                #expect(sent.request.method == .post)
                #expect(sent.request.path == "/v1/sync/writes")
                #expect(sent.request.headerFields[.authorization] == "Bearer session-1")
                let body = try #require(
                    JSONSerialization.jsonObject(with: Data((sent.body ?? "").utf8))
                        as? NSDictionary)
                let record: NSDictionary = [
                    "id": "00000000-0000-4000-8000-0000000000B1",
                    "weightKg": 72.4,
                    "measuredAt": 1_767_225_600_123,
                    "timeZone": "Asia/Tokyo",
                ]
                let updatedRecord: NSDictionary = [
                    "id": "00000000-0000-4000-8000-0000000000B1",
                    "weightKg": 72.4,
                    "measuredAt": 1_767_225_600_123,
                    "timeZone": "Asia/Tokyo",
                    "version": 2,
                ]
                let expected: NSDictionary = [
                    "clientState": [
                        "deviceId": "00000000-0000-4000-8000-0000000000D1",
                        "timeZone": "Asia/Tokyo",
                        "appVersion": "1.0.0",
                        "osVersion": "26.0",
                        "pendingWriteCount": 2,
                        "oldestPendingWriteAgeSeconds": 90,
                        "pendingPhotoCount": 0,
                    ],
                    "isFinalBatch": true,
                    "writes": [
                        [
                            "id": PushSyncWrites.createWriteId.uuidString,
                            "type": "create_weight_record",
                            "weightRecord": record,
                        ],
                        [
                            "id": PushSyncWrites.updateWriteId.uuidString,
                            "type": "update_weight_record",
                            "weightRecord": updatedRecord,
                        ],
                    ],
                ]
                #expect(body == expected)
            }
        }

        @Suite("ヘルスケアから取り込んだ記録を作る書き込みを送るとき")
        struct Imported {
            let transport: ClientTransportMock
            let client: NuToriAPIClient
            let clientState: SyncClientState
            let write: SyncWrite

            init() {
                clientState = .fixture()
                write = .createWeightRecord(
                    writeId: PushSyncWrites.createWriteId,
                    record: .fixture(
                        imported: .init(
                            sourceAppName: "Withings",
                            sourceBundleId: "com.withings.wiScaleNG",
                            healthKitSampleId: UUID(
                                uuidString: "00000000-0000-4000-8000-0000000000c1")!,
                            bodyFat: .init(
                                percentage: 18.5,
                                healthKitSampleId: UUID(
                                    uuidString: "00000000-0000-4000-8000-0000000000c2")!)
                        )
                    )
                )
                transport = .ok(json: #"{"results":[]}"#)
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: transport,
                    sessionToken: { nil }
                )
            }

            @Test("出どころと体脂肪率を添えて送ること")
            func sendsImportedSource() async throws {
                _ = try await client.pushSyncWrites(
                    [write], isFinalBatch: false, clientState: clientState)

                let sent = try #require(transport.requests.first)
                let body = try #require(
                    JSONSerialization.jsonObject(with: Data((sent.body ?? "").utf8))
                        as? [String: Any])
                let writes = try #require(body["writes"] as? [[String: Any]])
                let weightRecord = try #require(writes.first?["weightRecord"] as? NSDictionary)
                #expect(
                    weightRecord["imported"] as? NSDictionary == [
                        "sourceAppName": "Withings",
                        "sourceBundleId": "com.withings.wiScaleNG",
                        "healthkitSampleUuid": "00000000-0000-4000-8000-0000000000C1",
                        "bodyFat": [
                            "percentage": 18.5,
                            "healthkitSampleUuid": "00000000-0000-4000-8000-0000000000C2",
                        ],
                    ])
            }
        }

        @Suite("サーバーが知らない結果と理由を返したとき")
        struct UnknownResult {
            let client: NuToriAPIClient
            let clientState: SyncClientState

            init() {
                clientState = .fixture()
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(
                        json: """
                            {"results":[
                              {"writeId":"\(PushSyncWrites.createWriteId.uuidString)","result":"ignored_tombstone"},
                              {"writeId":"\(PushSyncWrites.updateWriteId.uuidString)","result":"rejected","rejectionReason":"too_old"}
                            ]}
                            """
                    ),
                    sessionToken: { "session-1" }
                )
            }

            @Test("落ちずに、知らない結果と理由として返すこと")
            func returnsUnknownOutcomes() async throws {
                let result = try await client.pushSyncWrites(
                    [], isFinalBatch: false, clientState: clientState)

                #expect(
                    result
                        == .pushed([
                            SyncWriteResult(
                                writeId: PushSyncWrites.createWriteId,
                                outcome: .unknown(result: "ignored_tombstone")),
                            SyncWriteResult(
                                writeId: PushSyncWrites.updateWriteId,
                                outcome: .rejected(.unknown(reason: "too_old"))),
                        ])
                )
            }
        }

        @Suite("書き込みが 500 件を超えていたときなど、サーバーが 400 を返したとき")
        struct BadRequest {
            let client: NuToriAPIClient
            let clientState: SyncClientState

            init() {
                clientState = .fixture()
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(status: .badRequest),
                    sessionToken: { "session-1" }
                )
            }

            @Test("要求が違うと返すこと")
            func returnsBadRequest() async throws {
                let result = try await client.pushSyncWrites(
                    [], isFinalBatch: false, clientState: clientState)
                #expect(result == .badRequest)
            }
        }

        @Suite("セッションが切れているとき")
        struct SessionExpired {
            let client: NuToriAPIClient
            let clientState: SyncClientState

            init() {
                clientState = .fixture()
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(status: .unauthorized),
                    sessionToken: { "session-1" }
                )
            }

            @Test("セッションが切れていると返すこと")
            func returnsSessionExpired() async throws {
                let result = try await client.pushSyncWrites(
                    [], isFinalBatch: false, clientState: clientState)
                #expect(result == .sessionExpired)
            }
        }

        @Suite("回数の歯止めにかかったとき")
        struct RateLimited {
            let client: NuToriAPIClient
            let clientState: SyncClientState

            init() {
                clientState = .fixture()
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(status: .tooManyRequests),
                    sessionToken: { "session-1" }
                )
            }

            @Test("回数の歯止めにかかったと返すこと")
            func returnsRateLimited() async throws {
                let result = try await client.pushSyncWrites(
                    [], isFinalBatch: false, clientState: clientState)
                #expect(result == .rateLimited)
            }
        }

        @Suite("文書に無い状態コードが返ったとき")
        struct UndocumentedStatus {
            let client: NuToriAPIClient
            let clientState: SyncClientState

            init() {
                clientState = .fixture()
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(status: .internalServerError),
                    sessionToken: { "session-1" }
                )
            }

            @Test("状態コードを添えて投げること")
            func throwsWithStatusCode() async {
                await #expect(throws: NuToriAPIClient.UndocumentedStatusError(statusCode: 500)) {
                    try await client.pushSyncWrites(
                        [], isFinalBatch: false, clientState: clientState)
                }
            }
        }
    }

    @Suite("変更を取りに行く")
    struct PullSyncChanges {
        @Suite("サーバーが変更を返したとき")
        struct Pulled {
            let transport: ClientTransportMock
            let client: NuToriAPIClient
            let clientState: SyncClientState

            init() {
                clientState = .fixture()
                transport = .ok(
                    json: """
                        {"changes":[
                          {"sequence":4,"kind":"weight_record","recordId":"00000000-0000-4000-8000-0000000000b1",
                           "record":{"id":"00000000-0000-4000-8000-0000000000b1","weightKg":71.25,
                                     "measuredAt":1767225600123,"timeZone":"Asia/Tokyo","version":3,
                                     "imported":{"sourceAppName":"Withings","sourceBundleId":"com.withings.wiScaleNG",
                                                 "healthkitSampleUuid":"00000000-0000-4000-8000-0000000000c1",
                                                 "bodyFat":{"percentage":18.5,"healthkitSampleUuid":"00000000-0000-4000-8000-0000000000c2"}}}},
                          {"sequence":5,"kind":"account_settings","recordId":"x","record":{"sendsUsageData":false}},
                          {"sequence":6,"kind":"weight_record","recordId":"y","record":{"unexpected":true}}
                        ],"hasMore":true,"nextAfterSequence":6,"startedOn":"2026-09-29"}
                        """
                )
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: transport,
                    sessionToken: { "session-1" }
                )
            }

            @Test("記録の種類ごとに中身を解いて返し、続きと使い始めた日を添えること")
            func returnsDecodedPage() async throws {
                let result = try await client.pullSyncChanges(
                    afterSequence: 3, clientState: clientState)

                let expectedRecord = SyncedWeightRecord.fixture(
                    weightKilograms: 71.25,
                    version: 3,
                    imported: .init(
                        sourceAppName: "Withings",
                        sourceBundleId: "com.withings.wiScaleNG",
                        healthKitSampleId: UUID(
                            uuidString: "00000000-0000-4000-8000-0000000000c1")!,
                        bodyFat: .init(
                            percentage: 18.5,
                            healthKitSampleId: UUID(
                                uuidString: "00000000-0000-4000-8000-0000000000c2")!)
                    )
                )
                #expect(
                    result
                        == .pulled(
                            SyncChangesPage(
                                changes: [
                                    .weightRecord(expectedRecord),
                                    .unknown(kind: "account_settings"),
                                    .unknown(kind: "weight_record"),
                                ],
                                hasMore: true,
                                nextAfterSequence: 6,
                                startedOn: "2026-09-29"
                            )
                        )
                )
            }

            @Test("前回の続きと端末の状態を、セッションのトークンつきで GET /v1/sync/changes に送ること")
            func sendsQuery() async throws {
                _ = try await client.pullSyncChanges(afterSequence: 3, clientState: clientState)

                let sent = try #require(transport.requests.first)
                let path = try #require(sent.request.path)
                let components = try #require(URLComponents(string: "https://api.example\(path)"))
                let query = Dictionary(
                    uniqueKeysWithValues: (components.queryItems ?? []).map {
                        ($0.name, $0.value ?? "")
                    })
                #expect(sent.request.method == .get)
                #expect(components.path == "/v1/sync/changes")
                #expect(sent.request.headerFields[.authorization] == "Bearer session-1")
                #expect(
                    query == [
                        "deviceId": "00000000-0000-4000-8000-0000000000D1",
                        "timeZone": "Asia/Tokyo",
                        "appVersion": "1.0.0",
                        "osVersion": "26.0",
                        "pendingWriteCount": "2",
                        "oldestPendingWriteAgeSeconds": "90",
                        "pendingPhotoCount": "0",
                        "afterSequence": "3",
                    ])
            }
        }

        @Suite("使い始めた日がまだ決まっていないとき")
        struct WithoutStartedOn {
            let client: NuToriAPIClient
            let clientState: SyncClientState

            init() {
                clientState = .fixture()
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(
                        json:
                            #"{"changes":[],"hasMore":false,"nextAfterSequence":0,"startedOn":null}"#
                    ),
                    sessionToken: { "session-1" }
                )
            }

            @Test("使い始めた日を nil にして返すこと")
            func returnsNilStartedOn() async throws {
                let result = try await client.pullSyncChanges(
                    afterSequence: 0, clientState: clientState)

                #expect(
                    result
                        == .pulled(
                            SyncChangesPage(
                                changes: [], hasMore: false, nextAfterSequence: 0, startedOn: nil)
                        ))
            }
        }

        @Suite("セッションが切れているとき")
        struct SessionExpired {
            let client: NuToriAPIClient
            let clientState: SyncClientState

            init() {
                clientState = .fixture()
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(status: .unauthorized),
                    sessionToken: { "session-1" }
                )
            }

            @Test("セッションが切れていると返すこと")
            func returnsSessionExpired() async throws {
                let result = try await client.pullSyncChanges(
                    afterSequence: 0, clientState: clientState)
                #expect(result == .sessionExpired)
            }
        }

        @Suite("回数の歯止めにかかったとき")
        struct RateLimited {
            let client: NuToriAPIClient
            let clientState: SyncClientState

            init() {
                clientState = .fixture()
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(status: .tooManyRequests),
                    sessionToken: { "session-1" }
                )
            }

            @Test("回数の歯止めにかかったと返すこと")
            func returnsRateLimited() async throws {
                let result = try await client.pullSyncChanges(
                    afterSequence: 0, clientState: clientState)
                #expect(result == .rateLimited)
            }
        }
    }
}
