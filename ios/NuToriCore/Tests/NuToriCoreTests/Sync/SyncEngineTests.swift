import Foundation
import HTTPTypes
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

@Suite("同期の働き")
struct SyncEngineTests {
    @Suite("体重記録を保存する")
    struct SaveWeightRecord {
        @Suite("新しく作るとき")
        struct Creating {
            let store: SyncStoreMock
            let engine: SyncEngine
            let firstWrite: WeightEntry.Write
            let secondWrite: WeightEntry.Write

            init() throws {
                let timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
                firstWrite = .create(
                    kilograms: 72.4, instant: SyncEngine.fixtureNow, timeZone: timeZone)
                secondWrite = .create(
                    kilograms: 72.5, instant: SyncEngine.fixtureNow, timeZone: timeZone)
                store = .ok()
                engine = .fixture(store: store, transport: .sync())
            }

            @Test("手で記録した版 1 の記録を、送り待ちに1件足す保存と同じ保存で置くこと")
            func savesRecordWithPendingWrite() async throws {
                try await engine.save(firstWrite)

                let pending = try #require(store.pending.first)
                let record = try #require(store.records.values.first)
                #expect(store.pending.count == 1)
                #expect(record.inputSource == .manual)
                #expect(record.version == 1)
                #expect(record.kilograms == 72.4)
                #expect(pending.operation == .createWeightRecord(record))
                #expect(pending.enqueuedAt == SyncEngine.fixtureNow)
            }

            @Test("記録の ID と書き込みの ID に、書き込みごとに違う UUID v4 を振ること")
            func assignsVersion4IdsPerWrite() async throws {
                try await engine.save(firstWrite)
                try await engine.save(secondWrite)

                let ids = store.pending.map(\.writeId) + Array(store.records.keys)
                #expect(Set(ids).count == 4)
                #expect(ids.allSatisfy { $0.uuidString.dropFirst(14).first == "4" })
            }
        }

        @Suite("手元にある記録を直すとき")
        struct Correcting {
            let store: SyncStoreMock
            let engine: SyncEngine
            let original: WeightRecord
            let corrected: WeightRecord

            init() throws {
                original = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                corrected = WeightRecord(
                    id: original.id,
                    kilograms: 72.0,
                    instant: original.instant,
                    timeZone: original.timeZone,
                    inputSource: .manual,
                    version: 2
                )
                store = .ok(records: [original])
                engine = .fixture(store: store, transport: .sync())
            }

            @Test("直した記録を置き、直す前の記録を添えた送り待ちを1件足すこと")
            func savesCorrectionWithPreviousRecord() async throws {
                try await engine.save(.correct(corrected))

                #expect(store.records[original.id] == corrected)
                let pending = try #require(store.pending.first)
                #expect(store.pending.count == 1)
                #expect(
                    pending.operation == .correctWeightRecord(corrected, previous: original))
            }
        }

        @Suite("手元に無い記録を直そうとしたとき")
        struct CorrectingUnknownRecord {
            let store: SyncStoreMock
            let engine: SyncEngine
            let unknown: WeightRecord

            init() throws {
                unknown = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                store = .ok()
                engine = .fixture(store: store, transport: .sync())
            }

            @Test("送り待ちに足さず、知らない記録だと投げること")
            func throwsUnknownRecord() async throws {
                await #expect(throws: SyncEngine.UnknownRecordError(recordId: unknown.id)) {
                    try await engine.save(.correct(unknown))
                }
                #expect(store.pending.isEmpty)
            }
        }

        @Suite("置き場が保存に失敗したとき")
        struct StoreFailing {
            struct Failure: Error, Equatable {}

            let reporting: ErrorReportingSessionMock
            let engine: SyncEngine
            let write: WeightEntry.Write

            init() {
                write = .create(kilograms: 72.4, instant: SyncEngine.fixtureNow, timeZone: .gmt)
                reporting = .ok()
                engine = .fixture(
                    store: .error(Failure()), transport: .sync(), errorReporting: reporting)
            }

            @Test("置き場のエラーをそのまま投げ、キャッシュの保存の失敗として送ること")
            func throwsStoreError() async throws {
                await #expect(throws: Failure()) {
                    try await engine.save(write)
                }
                #expect(reporting.reported == [.cacheSave])
            }
        }

        @Suite("置き場の保存が時間切れのとき")
        struct StoreTimedOut {
            let reporting: ErrorReportingSessionMock
            let engine: SyncEngine
            let write: WeightEntry.Write

            init() {
                write = .create(kilograms: 72.4, instant: SyncEngine.fixtureNow, timeZone: .gmt)
                reporting = .ok()
                engine = .fixture(
                    store: .error(URLError(.timedOut)), transport: .sync(),
                    errorReporting: reporting)
            }

            @Test("送らず、失敗を呼び出し側に返すこと")
            func doesNotReport() async {
                await #expect(throws: URLError.self) {
                    try await engine.save(write)
                }
                #expect(reporting.reported.isEmpty)
            }
        }

        @Suite("置き場の保存がキャンセルされたとき")
        struct StoreCancelled {
            let reporting: ErrorReportingSessionMock
            let engine: SyncEngine
            let write: WeightEntry.Write

            init() {
                write = .create(kilograms: 72.4, instant: SyncEngine.fixtureNow, timeZone: .gmt)
                reporting = .ok()
                engine = .fixture(
                    store: .error(CancellationError()), transport: .sync(),
                    errorReporting: reporting)
            }

            @Test("送らないこと")
            func doesNotReport() async {
                await #expect(throws: CancellationError.self) {
                    try await engine.save(write)
                }
                #expect(reporting.reported.isEmpty)
            }
        }
    }

    @Suite("送り待ちを送る")
    struct PushPendingWrites {
        @Suite("送り待ちが3件あるとき")
        struct ThreePending {
            let store: SyncStoreMock
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() throws {
                let records = try [
                    WeightRecord.manual(72.4, at: "2026-09-22T07:12:00+09:00", in: "Asia/Tokyo"),
                    WeightRecord.manual(72.5, at: "2026-09-23T07:12:00+09:00", in: "Asia/Tokyo"),
                    WeightRecord.manual(72.6, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo"),
                ]
                store = .ok(
                    records: records,
                    pendingWrites: [
                        .creating(records[0], ageSeconds: 600),
                        .creating(records[1], ageSeconds: 30),
                        .creating(records[2]),
                    ]
                )
                transport = .sync()
                engine = .fixture(store: store, transport: transport)
            }

            @Test("1つの要求で順に送り、送り切った印を付け、送り待ちを空にすること")
            func pushesInOneFinalRequest() async throws {
                let result = try await engine.sync()

                let bodies = try transport.pushBodies
                #expect(bodies.count == 1)
                #expect(bodies[0].writes.count == 3)
                #expect(bodies[0].isFinalBatch)
                #expect(store.pending.isEmpty)
                #expect(result == SyncResult(rejectedWrites: [], ending: .finished))
            }

            @Test("端末の状態として、タイムゾーン、送り待ちの件数、いちばん古い経過時間、写真の送り残し 0 を添えること")
            func attachesClientState() async throws {
                _ = try await engine.sync()

                let bodies = try transport.pushBodies
                let clientState = bodies[0].clientState
                #expect(clientState.timeZone == "Asia/Tokyo")
                #expect(clientState.pendingWriteCount == 3)
                #expect(clientState.oldestPendingWriteAgeSeconds == 600)
                #expect(clientState.pendingPhotoCount == 0)
                #expect(
                    clientState.deviceId == "00000000-0000-4000-8000-0000000000D1")
            }

            @Test("送り切ってから取りに行くこと")
            func pullsAfterPushing() async throws {
                _ = try await engine.sync()

                #expect(transport.requests.map(\.request.method) == [.post, .get])
                #expect(try transport.pullQueries[0]["pendingWriteCount"] == "0")
            }
        }

        @Suite("送り待ちが501件あるとき")
        struct MoreThanOneRequest {
            let store: SyncStoreMock
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() throws {
                let record = try WeightRecord.manual(
                    72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                store = .ok(pendingWrites: (0..<501).map { _ in .creating(record) })
                transport = .sync()
                engine = .fixture(store: store, transport: transport)
            }

            @Test("500 件と 1 件の2回に分け、最後の要求にだけ送り切った印を付けること")
            func splitsAndMarksLastRequest() async throws {
                _ = try await engine.sync()

                let bodies = try transport.pushBodies
                #expect(bodies.map(\.writes.count) == [500, 1])
                #expect(bodies.map(\.isFinalBatch) == [false, true])
                #expect(store.pending.isEmpty)
            }
        }

        @Suite("回数の歯止めにかかったとき")
        struct RateLimited {
            let store: SyncStoreMock
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() throws {
                let record = try WeightRecord.manual(
                    72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                store = .ok(records: [record], pendingWrites: [.creating(record)])
                transport = .sync(pushStatus: .tooManyRequests)
                engine = .fixture(store: store, transport: transport)
            }

            @Test("送り待ちに残し、取りに行かずに止まること")
            func keepsPendingAndStops() async throws {
                let result = try await engine.sync()

                #expect(store.pending.count == 1)
                #expect(store.records.count == 1)
                #expect(transport.requests.count == 1)
                #expect(result == SyncResult(rejectedWrites: [], ending: .stopped(.rateLimited)))
            }
        }

        @Suite("インターネットにつながらないとき")
        struct Offline {
            let store: SyncStoreMock
            let engine: SyncEngine

            init() throws {
                let record = try WeightRecord.manual(
                    72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                store = .ok(records: [record], pendingWrites: [.creating(record)])
                engine = .fixture(
                    store: store, transport: .error(URLError(.notConnectedToInternet)))
            }

            @Test("送り待ちに残して止まること")
            func keepsPendingAndStops() async throws {
                let result = try await engine.sync()

                #expect(store.pending.count == 1)
                #expect(result == SyncResult(rejectedWrites: [], ending: .stopped(.unavailable)))
            }
        }

        @Suite("サーバーが書き込みを受け付けなかったとき")
        struct Rejected {
            let store: SyncStoreMock
            let engine: SyncEngine
            let created: WeightRecord
            let previous: WeightRecord
            let corrected: WeightRecord
            let createWrite: PendingWrite
            let correctWrite: PendingWrite

            init() throws {
                created = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                previous = try .manual(71.0, at: "2026-09-23T07:12:00+09:00", in: "Asia/Tokyo")
                corrected = WeightRecord(
                    id: previous.id,
                    kilograms: 500,
                    instant: previous.instant,
                    timeZone: previous.timeZone,
                    inputSource: .manual,
                    version: 2
                )
                createWrite = .creating(created)
                correctWrite = .correcting(corrected, previous: previous)
                store = .ok(
                    records: [created, corrected],
                    pendingWrites: [createWrite, correctWrite]
                )
                engine = .fixture(
                    store: store,
                    transport: .sync(rejectedWriteIndexes: [0, 1])
                )
            }

            @Test("送り待ちから外して、送り直さないこと")
            func removesFromPending() async throws {
                _ = try await engine.sync()

                #expect(store.pending.isEmpty)
            }

            @Test("新しく作った記録は消し、直した記録は直す前の状態に戻すこと")
            func revertsRecords() async throws {
                _ = try await engine.sync()

                #expect(store.records[created.id] == nil)
                #expect(store.records[previous.id] == previous)
            }

            @Test("画面に出すために、記録と理由を結果に返すこと")
            func returnsRejectedWrites() async throws {
                let result = try await engine.sync()

                #expect(
                    result.rejectedWrites == [
                        RejectedWrite(
                            writeId: createWrite.writeId, record: created, reason: .outOfRange),
                        RejectedWrite(
                            writeId: correctWrite.writeId, record: corrected, reason: .outOfRange),
                    ]
                )
                #expect(result.ending == .finished)
            }
        }

        @Suite("ヘルスケアで元のサンプルが消えた書き込みが送り待ちにあるとき")
        struct SourceDeleted {
            let store: SyncStoreMock
            let transport: ClientTransportMock
            let engine: SyncEngine
            let recordId: UUID
            let kept: WeightRecord

            init() throws {
                recordId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000b1"))
                kept = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                store = .ok(
                    records: [kept],
                    pendingWrites: [
                        PendingWrite(
                            writeId: UUID(),
                            enqueuedAt: SyncEngine.fixtureNow,
                            operation: .sourceDeletedWeightRecord(recordId: recordId)
                        )
                    ]
                )
                transport = .sync(rejectedWriteIndexes: [0])
                engine = .fixture(store: store, transport: transport)
            }

            @Test("消えた体重記録の ID を名指して送ること")
            func sendsRecordId() async throws {
                _ = try await engine.sync()

                let write = try #require(transport.pushBodies.first?.writes.first)
                #expect(write.type == "source_deleted_weight_record")
                #expect(write.weightRecordId == recordId.uuidString)
            }

            @Test("サーバーが受け付けなくても、送り待ちから外して送り直さず、記録は戻さず、結果にも出さないこと")
            func dropsWithoutRevertingOrReporting() async throws {
                let result = try await engine.sync()

                #expect(store.pending.isEmpty)
                #expect(store.records[kept.id] == kept)
                #expect(result == SyncResult(rejectedWrites: [], ending: .finished))
            }
        }

        @Suite("同じ記録の直しが2回続けて受け付けられなかったとき")
        struct RejectedTwiceForOneRecord {
            let store: SyncStoreMock
            let engine: SyncEngine
            let original: WeightRecord

            init() throws {
                original = try .manual(71.0, at: "2026-09-23T07:12:00+09:00", in: "Asia/Tokyo")
                let first = WeightRecord(
                    id: original.id, kilograms: 500, instant: original.instant,
                    timeZone: original.timeZone, inputSource: .manual, version: 2)
                let second = WeightRecord(
                    id: original.id, kilograms: 501, instant: original.instant,
                    timeZone: original.timeZone, inputSource: .manual, version: 3)
                store = .ok(
                    records: [second],
                    pendingWrites: [
                        .correcting(first, previous: original),
                        .correcting(second, previous: first),
                    ]
                )
                engine = .fixture(store: store, transport: .sync(rejectedWriteIndexes: [0, 1]))
            }

            @Test("サーバーにある、いちばん前の状態に戻すこと")
            func revertsToEarliestPrevious() async throws {
                _ = try await engine.sync()

                #expect(store.records[original.id] == original)
            }
        }
    }

    @Suite("変更を取りに行く")
    struct PullChanges {
        @Suite("続きがあるとき")
        struct HasMore {
            let store: SyncStoreMock
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() {
                store = .ok()
                transport = .sync(pullPages: [
                    """
                    {"changes":[{"sequence":1,"kind":"weight_record","recordId":"00000000-0000-4000-8000-0000000000b1",
                      "record":{"id":"00000000-0000-4000-8000-0000000000b1","weightKg":72.4,
                        "measuredAt":1767225600000,"timeZone":"Asia/Tokyo","version":1}}],
                     "hasMore":true,"nextAfterSequence":1,"startedOn":"2026-09-01"}
                    """,
                    """
                    {"changes":[{"sequence":2,"kind":"weight_record","recordId":"00000000-0000-4000-8000-0000000000b2",
                      "record":{"id":"00000000-0000-4000-8000-0000000000b2","weightKg":72.0,
                        "measuredAt":1767312000000,"timeZone":"Asia/Tokyo","version":1}}],
                     "hasMore":false,"nextAfterSequence":2,"startedOn":"2026-09-01"}
                    """,
                ])
                engine = .fixture(store: store, transport: transport)
            }

            @Test("続きの旗が落ちるまで、前回の続きから取りに行くこと")
            func pullsUntilNoMore() async throws {
                _ = try await engine.sync()

                #expect(try transport.pullQueries.map { $0["afterSequence"] } == ["0", "1"])
            }

            @Test("落ちるまでは初回の取得を終えたとみなさず、落ちたら終えたとみなすこと")
            func completesInitialPullOnlyAtTheEnd() async throws {
                _ = try await engine.sync()

                #expect(store.appliedChanges.map(\.state.hasCompletedInitialPull) == [false, true])
            }

            @Test("通し番号と使い始めた日を、記録と同じ保存で進めること")
            func advancesStateWithRecords() async throws {
                _ = try await engine.sync()

                #expect(store.appliedChanges.map(\.records.count) == [1, 1])
                #expect(store.appliedChanges.map(\.state.afterSequence) == [1, 2])
                #expect(store.state?.startedOn == "2026-09-01")
            }
        }

        @Suite("手元の記録と同じ ID の記録が届いたとき")
        struct ReplacingCache {
            let store: SyncStoreMock
            let engine: SyncEngine
            let local: WeightRecord

            init() throws {
                local = try WeightRecord(
                    id: #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")),
                    kilograms: 70.0,
                    instant: Date(timeIntervalSince1970: 1_767_225_600),
                    timeZone: #require(TimeZone(identifier: "Asia/Tokyo")),
                    inputSource: .manual,
                    version: 1
                )
                store = .ok(records: [local])
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[{"sequence":3,"kind":"weight_record","recordId":"00000000-0000-4000-8000-0000000000b1",
                          "record":{"id":"00000000-0000-4000-8000-0000000000b1","weightKg":71.25,
                            "measuredAt":1767225600000,"timeZone":"Asia/Tokyo","version":3,
                            "imported":{"sourceAppName":"Withings","sourceBundleId":"com.withings.wiScaleNG",
                              "healthkitSampleUuid":"00000000-0000-4000-8000-0000000000c1",
                              "bodyFat":{"percentage":18.5,"healthkitSampleUuid":"00000000-0000-4000-8000-0000000000c2"}}}}],
                         "hasMore":false,"nextAfterSequence":3,"startedOn":null}
                        """
                    ])
                )
            }

            @Test("サーバーの値と版で、キャッシュの記録を置き換えること")
            func replacesRecord() async throws {
                _ = try await engine.sync()

                let replaced = try #require(store.records[local.id])
                #expect(replaced.kilograms == 71.25)
                #expect(replaced.version == 3)
                #expect(
                    replaced.inputSource
                        == .imported(
                            WeightRecord.ImportedSource(
                                appName: "Withings",
                                bundleId: "com.withings.wiScaleNG",
                                healthKitSampleId: try #require(
                                    UUID(uuidString: "00000000-0000-4000-8000-0000000000c1")),
                                bodyFat: WeightRecord.ImportedSource.BodyFat(
                                    percentage: 18.5,
                                    healthKitSampleId: try #require(
                                        UUID(uuidString: "00000000-0000-4000-8000-0000000000c2"))
                                )
                            )
                        )
                )
                #expect(store.records.count == 1)
            }
        }

        @Suite("削除の印が届いたとき")
        struct Deletions {
            let store: SyncStoreMock
            let engine: SyncEngine
            let removed: WeightRecord
            let kept: WeightRecord

            init() throws {
                let removedId = "00000000-0000-4000-8000-0000000000b1"
                let unknownId = "00000000-0000-4000-8000-0000000000b9"
                removed = WeightRecord(
                    id: try #require(UUID(uuidString: removedId)),
                    kilograms: 70.0,
                    instant: Date(timeIntervalSince1970: 1_767_225_600),
                    timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                    inputSource: .manual,
                    version: 1
                )
                kept = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                store = .ok(records: [removed, kept])
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          {"sequence":6,"kind":"weight_record_deletion","recordId":"\(removedId)","record":{}},
                          {"sequence":7,"kind":"weight_record_deletion","recordId":"\(unknownId)","record":{}}
                        ],"hasMore":false,"nextAfterSequence":7,"startedOn":null}
                        """
                    ])
                )
            }

            @Test("削除の印が指す記録をキャッシュから消し、ほかの記録は残すこと")
            func removesOnlyTheRecord() async throws {
                _ = try await engine.sync()

                #expect(store.records[removed.id] == nil)
                #expect(store.records[kept.id] == kept)
            }

            @Test("キャッシュに無い ID の削除の印は読み飛ばし、通し番号は進めること")
            func skipsUnknownIdAndAdvances() async throws {
                let result = try await engine.sync()

                #expect(store.state?.afterSequence == 7)
                #expect(result.ending == .finished)
            }
        }

        @Suite("知らない種類の記録や、読めない中身が届いたとき")
        struct UnknownKinds {
            let store: SyncStoreMock
            let engine: SyncEngine

            init() {
                store = .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          {"sequence":4,"kind":"meal","recordId":"x","record":{"calories":500}},
                          {"sequence":5,"kind":"weight_record","recordId":"y","record":{"unexpected":true}}
                        ],"hasMore":false,"nextAfterSequence":5,"startedOn":null}
                        """
                    ])
                )
            }

            @Test("落ちずに読み飛ばし、通し番号は進めること")
            func skipsAndAdvances() async throws {
                let result = try await engine.sync()

                #expect(store.records.isEmpty)
                #expect(store.state?.afterSequence == 5)
                #expect(result.ending == .finished)
            }
        }

        @Suite("読める種類が前より増えて、更新して最初に同期するとき")
        struct NewReadableKinds {
            let store: SyncStoreMock
            let transport: ClientTransportMock
            let engine: SyncEngine
            let cached: WeightRecord

            init() throws {
                cached = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                store = .ok(
                    records: [cached],
                    state: .fixture(
                        afterSequence: 42, hasCompletedInitialPull: true,
                        readableKinds: ["weight-record"])
                )
                transport = .sync()
                engine = .fixture(
                    store: store, transport: transport,
                    readableKinds: ["account-settings", "weight-record"])
            }

            @Test("通し番号を最初に戻して取り直し、キャッシュは捨てず、初回の取得を終えた印は戻さないこと")
            func restartsFromTheBeginning() async throws {
                _ = try await engine.sync()

                #expect(try transport.pullQueries.map { $0["afterSequence"] } == ["0"])
                #expect(store.records[cached.id] == cached)
                #expect(store.state?.hasCompletedInitialPull == true)
                #expect(store.state?.readableKinds == ["account-settings", "weight-record"])
            }
        }

        @Suite("2つの種類を同時に読めるようになって、更新して最初に同期するとき")
        struct TwoNewReadableKinds {
            let store: SyncStoreMock
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() {
                store = .ok(
                    state: .fixture(
                        afterSequence: 42, hasCompletedInitialPull: true,
                        readableKinds: ["weight-record"])
                )
                transport = .sync()
                engine = .fixture(
                    store: store, transport: transport,
                    readableKinds: ["account-settings", "meal", "weight-record"])
            }

            @Test("通し番号を最初に戻して取り直し、読めた種類に両方を残すこと")
            func restartsAndRemembersBoth() async throws {
                _ = try await engine.sync()

                #expect(try transport.pullQueries.map { $0["afterSequence"] } == ["0"])
                #expect(
                    store.state?.readableKinds == ["account-settings", "meal", "weight-record"])
            }
        }

        @Suite("同じ種類で2回目に同期するとき")
        struct SameReadableKinds {
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() {
                transport = .sync()
                engine = .fixture(
                    store: .ok(
                        state: .fixture(
                            afterSequence: 42, hasCompletedInitialPull: true,
                            readableKinds: ["weight-record"]
                        )
                    ),
                    transport: transport
                )
            }

            @Test("前回の続きから取りに行くこと")
            func continuesFromLastSequence() async throws {
                _ = try await engine.sync()

                #expect(try transport.pullQueries.map { $0["afterSequence"] } == ["42"])
            }
        }

        @Suite("手の記録の版がキャッシュより大きいとき")
        struct RevisedManualRecord {
            let export: WeightHealthExportMock
            let engine: SyncEngine
            let revisedId: UUID

            init() throws {
                revisedId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000b1"))
                let freshId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000b2"))
                let importedId = try #require(
                    UUID(uuidString: "00000000-0000-4000-8000-0000000000b3"))
                let cachedManual = try WeightRecord.manual(
                    70.0, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo", id: revisedId,
                    version: 1)
                let cachedImported = WeightRecord(
                    id: importedId,
                    kilograms: 71.0,
                    instant: try Date("2026-09-24T08:00:00+09:00", strategy: .iso8601),
                    timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                    inputSource: .imported(
                        WeightRecord.ImportedSource(
                            appName: "体重計アプリ",
                            bundleId: "com.example.scale",
                            healthKitSampleId: try #require(
                                UUID(uuidString: "00000000-0000-4000-8000-0000000000c9")),
                            bodyFat: nil
                        )
                    ),
                    version: 1
                )
                export = .ok()
                engine = .fixture(
                    store: .ok(records: [cachedManual, cachedImported]),
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          {"sequence":8,"kind":"weight_record","recordId":"\(revisedId.uuidString)",
                            "record":{"id":"\(revisedId.uuidString)","weightKg":73.1,
                              "measuredAt":1767225600000,"timeZone":"Asia/Tokyo","version":4}},
                          {"sequence":9,"kind":"weight_record","recordId":"\(freshId.uuidString)",
                            "record":{"id":"\(freshId.uuidString)","weightKg":69.0,
                              "measuredAt":1767312000000,"timeZone":"Asia/Tokyo","version":1}},
                          {"sequence":10,"kind":"weight_record","recordId":"\(importedId.uuidString)",
                            "record":{"id":"\(importedId.uuidString)","weightKg":71.4,
                              "measuredAt":1767312000000,"timeZone":"Asia/Tokyo","version":5,
                              "imported":{"sourceAppName":"体重計アプリ","sourceBundleId":"com.example.scale",
                                "healthkitSampleUuid":"00000000-0000-4000-8000-0000000000c9"}}}
                        ],"hasMore":false,"nextAfterSequence":10,"startedOn":null}
                        """
                    ]),
                    weightHealthExport: export
                )
            }

            @Test("その手の記録だけをヘルスケアに書き直すこと")
            func exportsOnlyTheRevisedManualRecord() async throws {
                _ = try await engine.sync()

                #expect(export.writes.map(\.id) == [revisedId])
                #expect(export.writes.map(\.version) == [4])
                #expect(export.writes.map(\.kilograms) == [73.1])
            }
        }

        @Suite("ヘルスケアへの書き直しが失敗したとき")
        struct ExportFails {
            let store: SyncStoreMock
            let engine: SyncEngine
            let revised: WeightRecord

            init() throws {
                revised = try WeightRecord.manual(
                    70.0, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo", version: 1)
                store = .ok(records: [revised])
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          {"sequence":8,"kind":"weight_record","recordId":"\(revised.id.uuidString)",
                            "record":{"id":"\(revised.id.uuidString)","weightKg":73.1,
                              "measuredAt":1767225600000,"timeZone":"Asia/Tokyo","version":4}}
                        ],"hasMore":false,"nextAfterSequence":8,"startedOn":null}
                        """
                    ]),
                    weightHealthExport: WeightHealthExportMock.error(ExportFailure())
                )
            }

            @Test("届いた記録はキャッシュに入れ、同期は終えること")
            func keepsThePulledRecord() async throws {
                let result = try await engine.sync()

                #expect(result.ending == .finished)
                #expect(store.records[revised.id]?.version == 4)
                #expect(store.records[revised.id]?.kilograms == 73.1)
            }

            private struct ExportFailure: Error {}
        }
    }
}
