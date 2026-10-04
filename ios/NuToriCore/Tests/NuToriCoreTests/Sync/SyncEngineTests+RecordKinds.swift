import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("記録の種類の登録簿で振り分ける")
    struct RecordKinds {
        @Suite("複数の種類の送り待ちを送るとき")
        struct Pushing {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine
            let note: PendingEntry
            let created: PendingWeightRecordWrite
            let rejectedCreated: PendingWeightRecordWrite

            init() throws {
                note = RecordKindMock.entry(recordId: UUID(), ageSeconds: 30)
                created = .creating(
                    try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo"),
                    ageSeconds: 20)
                rejectedCreated = .creating(
                    try .manual(72.0, at: "2026-09-25T07:12:00+09:00", in: "Asia/Tokyo"),
                    ageSeconds: 10)
                store = try .ok(
                    records: [
                        created.write.weightRecord, rejectedCreated.write.weightRecord,
                    ],
                    pendingWrites: [created, rejectedCreated], pendingEntries: [note],
                    recordKinds: [RecordKindMock.ok()])
                transport = .sync(rejectedWriteIndexes: [2], currents: [2: .absent])
                engine = .fixture(store: store, transport: transport)
            }

            @Test("種類ごとに、送る書き込みにすること")
            func buildsWritesByKind() async throws {
                _ = try await engine.sync()

                let writes = try #require(transport.pushBodies.first).writes
                #expect(
                    writes.map(\.type) == [
                        "source_deleted_weight_record", "create_weight_record",
                        "create_weight_record",
                    ])
            }

            @Test("結果を受け取った送り待ちを、種類を問わず1つの結果で外すこと")
            func resolvesAllInOneResult() async throws {
                _ = try await engine.sync()

                #expect(store.entries.isEmpty)
            }

            @Test("受け付けなかった書き込みの扱いは、その書き込みの種類が決めること")
            func rejectionIsDecidedByKind() async throws {
                let result = try await engine.sync()

                #expect(result.rejectedWrites.map(\.writeId) == [rejectedCreated.writeId])
                #expect(store.records[rejectedCreated.write.weightRecord.id] == nil)
                #expect(store.records[created.write.weightRecord.id] != nil)
            }
        }

        @Suite("登録簿に無い種類の送り待ちがあるとき")
        struct PushingUnknownKind {
            let engine: SyncEngine

            init() throws {
                engine = .fixture(
                    store: SyncBoxMock(
                        kinds: RecordKindRegistry([WeightRecordKindMock()]),
                        cache: RecordCacheMock(),
                        pendingEntries: [RecordKindMock.entry(recordId: UUID())]),
                    transport: .sync())
            }

            @Test("送らずに、登録簿に無い種類として投げること")
            func throwsUnknownKind() async throws {
                await #expect(throws: UnknownRecordKindError.notRegistered(.accountSettings)) {
                    _ = try await engine.sync()
                }
            }
        }

        @Suite("登録簿の種類の書き込みを作れないとき")
        struct BuildingWriteFailing {
            let engine: SyncEngine

            init() throws {
                engine = .fixture(
                    store: try .ok(
                        pendingEntries: [RecordKindMock.entry(recordId: UUID())],
                        recordKinds: [RecordKindMock.error(.init())]),
                    transport: .sync())
            }

            @Test("種類の失敗を投げること")
            func throwsKindFailure() async throws {
                await #expect(throws: RecordKindMock.Failure()) {
                    _ = try await engine.sync()
                }
            }
        }

        @Suite("複数の種類の変更を取りに行くとき")
        struct Pulling {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() throws {
                store = try .ok(recordKinds: [RecordKindMock.ok()])
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          {"sequence":1,"kind":"note","recordId":"n1","record":{}},
                          {"sequence":2,"kind":"weight_record","recordId":"00000000-0000-4000-8000-0000000000b1",
                            "record":{"id":"00000000-0000-4000-8000-0000000000b1","weightKg":72.4,
                              "measuredAt":1767225600000,"timeZone":"Asia/Tokyo","version":1}},
                          {"sequence":3,"kind":"note","recordId":"n2","record":{}},
                          {"sequence":4,"kind":"unregistered","recordId":"u1","record":{}}
                        ],"hasMore":false,"nextAfterSequence":4,"startedOn":null}
                        """
                    ])
                )
            }

            @Test("変更を、種類の名前ごとに、通し番号と同じ結果で箱に渡すこと")
            func handsOwnedChangesToBox() async throws {
                _ = try await engine.sync()

                #expect(
                    store.appliedKindChanges.map(\.kind) == [.accountSettings, .weightRecord])
                #expect(store.cache.appliedCount(of: .accountSettings) == 2)
                #expect(store.records.count == 1)
                #expect(store.appliedSyncStates.map(\.afterSequence) == [4])
            }

            @Test("登録簿に無い種類の変更は、読み飛ばして同期を進めること")
            func skipsUnregisteredKind() async throws {
                _ = try await engine.sync()

                #expect(store.appliedKindChanges.flatMap(\.changes).count == 3)
                #expect(store.state?.afterSequence == 4)
            }
        }
    }
}

extension WeightRecordWrite {
    fileprivate var weightRecord: WeightRecord {
        switch self {
        case .createWeightRecord(let record), .correctWeightRecord(let record):
            record
        case .sourceDeletedWeightRecord:
            preconditionFailure("体重記録を作る書き込みではない")
        }
    }
}
