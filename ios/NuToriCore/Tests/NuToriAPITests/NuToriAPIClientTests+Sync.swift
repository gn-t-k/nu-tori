import Foundation
import HTTPTypes
import Testing

@testable import NuToriAPI

extension NuToriAPIClientTests {
    @Suite("送り待ちを送る")
    struct PushSyncWrites {
        static let clientState = SyncClientState(
            deviceId: UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!,
            timeZone: TimeZone(identifier: "Asia/Tokyo")!,
            appVersion: "1.0.0",
            osVersion: "26.0",
            pendingWriteCount: 2,
            oldestPendingWriteAge: .seconds(90),
            pendingPhotoCount: 0
        )
        static let createWriteId = UUID(uuidString: "00000000-0000-4000-8000-0000000000a1")!
        static let updateWriteId = UUID(uuidString: "00000000-0000-4000-8000-0000000000a2")!
        static let recordId = UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")!

        @Suite("サーバーが書き込みごとの結果を返したとき")
        struct Pushed {
            let transport: ClientTransportMock
            let client: NuToriAPIClient
            let writes: [SyncWrite]

            init() {
                let record = SyncedWeightRecord(
                    id: PushSyncWrites.recordId,
                    weightKilograms: 72.4,
                    measuredAt: Date(timeIntervalSince1970: 1_767_225_600.123),
                    timeZone: TimeZone(identifier: "Asia/Tokyo")!,
                    version: 2,
                    imported: nil
                )
                writes = [
                    .createWeightRecord(writeId: PushSyncWrites.createWriteId, record: record),
                    .updateWeightRecord(writeId: PushSyncWrites.updateWriteId, record: record),
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
                    writes, isFinalBatch: true, clientState: PushSyncWrites.clientState)

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
                    writes, isFinalBatch: true, clientState: PushSyncWrites.clientState)

                let sent = try #require(transport.requests.first)
                #expect(sent.request.method == .post)
                #expect(sent.request.path == "/v1/sync/writes")
                #expect(sent.request.headerFields[.authorization] == "Bearer session-1")
                let body = try #require(
                    JSONSerialization.jsonObject(with: Data((sent.body ?? "").utf8))
                        as? NSDictionary)
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
                            "weightRecord": [
                                "id": PushSyncWrites.recordId.uuidString,
                                "weightKg": 72.4,
                                "measuredAt": 1_767_225_600_123,
                                "timeZone": "Asia/Tokyo",
                            ],
                        ],
                        [
                            "id": PushSyncWrites.updateWriteId.uuidString,
                            "type": "update_weight_record",
                            "weightRecord": [
                                "id": PushSyncWrites.recordId.uuidString,
                                "weightKg": 72.4,
                                "measuredAt": 1_767_225_600_123,
                                "timeZone": "Asia/Tokyo",
                                "version": 2,
                            ],
                        ],
                    ],
                ]
                #expect(body == expected)
            }
        }

        @Suite("ヘルスケアから取り込んだ記録を作る書き込みを送るとき")
        struct Imported {
            @Test("出どころと体脂肪率を添えて送ること")
            func sendsImportedSource() async throws {
                let transport = ClientTransportMock.ok(json: #"{"results":[]}"#)
                let client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: transport,
                    sessionToken: { nil }
                )
                let sampleId = UUID(uuidString: "00000000-0000-4000-8000-0000000000c1")!
                let bodyFatSampleId = UUID(uuidString: "00000000-0000-4000-8000-0000000000c2")!
                let record = SyncedWeightRecord(
                    id: PushSyncWrites.recordId,
                    weightKilograms: 71.25,
                    measuredAt: Date(timeIntervalSince1970: 1_767_225_600),
                    timeZone: TimeZone(identifier: "Asia/Tokyo")!,
                    version: 1,
                    imported: .init(
                        sourceAppName: "Withings",
                        sourceBundleId: "com.withings.wiScaleNG",
                        healthKitSampleId: sampleId,
                        bodyFat: .init(percentage: 18.5, healthKitSampleId: bodyFatSampleId)
                    )
                )

                _ = try await client.pushSyncWrites(
                    [.createWeightRecord(writeId: PushSyncWrites.createWriteId, record: record)],
                    isFinalBatch: false, clientState: PushSyncWrites.clientState)

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
                        "healthkitSampleUuid": sampleId.uuidString,
                        "bodyFat": [
                            "percentage": 18.5,
                            "healthkitSampleUuid": bodyFatSampleId.uuidString,
                        ],
                    ])
            }
        }

        @Suite("サーバーが状態コードで断ったとき")
        struct Declined {
            @Test("書き込みが 500 件を超えたときの 400 を、要求が違うと返すこと")
            func returnsBadRequest() async throws {
                let client = Self.client(status: .badRequest)
                let result = try await client.pushSyncWrites(
                    [], isFinalBatch: false, clientState: PushSyncWrites.clientState)
                #expect(result == .badRequest)
            }

            @Test("セッションが切れていると返すこと")
            func returnsSessionExpired() async throws {
                let client = Self.client(status: .unauthorized)
                let result = try await client.pushSyncWrites(
                    [], isFinalBatch: false, clientState: PushSyncWrites.clientState)
                #expect(result == .sessionExpired)
            }

            @Test("回数の歯止めにかかったと返すこと")
            func returnsRateLimited() async throws {
                let client = Self.client(status: .tooManyRequests)
                let result = try await client.pushSyncWrites(
                    [], isFinalBatch: false, clientState: PushSyncWrites.clientState)
                #expect(result == .rateLimited)
            }

            @Test("文書に無い状態コードは、状態コードを添えて投げること")
            func throwsUndocumentedStatus() async {
                let client = Self.client(status: .internalServerError)
                await #expect(throws: NuToriAPIClient.UndocumentedStatusError(statusCode: 500)) {
                    try await client.pushSyncWrites(
                        [], isFinalBatch: false, clientState: PushSyncWrites.clientState)
                }
            }

            static func client(status: HTTPResponse.Status) -> NuToriAPIClient {
                NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(status: status),
                    sessionToken: { "session-1" }
                )
            }
        }
    }

    @Suite("変更を取りに行く")
    struct PullSyncChanges {
        @Suite("サーバーが変更を返したとき")
        struct Pulled {
            let transport: ClientTransportMock
            let client: NuToriAPIClient

            init() {
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
                    afterSequence: 3, clientState: PushSyncWrites.clientState)

                let expectedRecord = SyncedWeightRecord(
                    id: PushSyncWrites.recordId,
                    weightKilograms: 71.25,
                    measuredAt: Date(timeIntervalSince1970: 1_767_225_600.123),
                    timeZone: TimeZone(identifier: "Asia/Tokyo")!,
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
                _ = try await client.pullSyncChanges(
                    afterSequence: 3, clientState: PushSyncWrites.clientState)

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
            @Test("使い始めた日を nil にして返すこと")
            func returnsNilStartedOn() async throws {
                let client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(
                        json:
                            #"{"changes":[],"hasMore":false,"nextAfterSequence":0,"startedOn":null}"#
                    ),
                    sessionToken: { "session-1" }
                )

                let result = try await client.pullSyncChanges(
                    afterSequence: 0, clientState: PushSyncWrites.clientState)

                #expect(
                    result
                        == .pulled(
                            SyncChangesPage(
                                changes: [], hasMore: false, nextAfterSequence: 0, startedOn: nil)
                        ))
            }
        }

        @Suite("サーバーが状態コードで断ったとき")
        struct Declined {
            @Test("セッションが切れていると返すこと")
            func returnsSessionExpired() async throws {
                let client = Self.client(status: .unauthorized)
                let result = try await client.pullSyncChanges(
                    afterSequence: 0, clientState: PushSyncWrites.clientState)
                #expect(result == .sessionExpired)
            }

            @Test("回数の歯止めにかかったと返すこと")
            func returnsRateLimited() async throws {
                let client = Self.client(status: .tooManyRequests)
                let result = try await client.pullSyncChanges(
                    afterSequence: 0, clientState: PushSyncWrites.clientState)
                #expect(result == .rateLimited)
            }

            static func client(status: HTTPResponse.Status) -> NuToriAPIClient {
                NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(status: status),
                    sessionToken: { "session-1" }
                )
            }
        }
    }
}
