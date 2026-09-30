import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("記録の種類の登録簿で振り分ける")
    struct RecordKinds {
        @Suite("登録簿にある種類と無い種類の送り待ちを送るとき")
        struct Pushing {
            let store: SyncStoreMock
            let transport: ClientTransportMock
            let engine: SyncEngine
            let registered: PendingEntry
            let legacy: PendingWrite
            let rejectedLegacy: PendingWrite

            init() throws {
                registered = RecordKindMock.entry(recordId: UUID(), ageSeconds: 30)
                legacy = .creating(
                    try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo"),
                    ageSeconds: 20)
                rejectedLegacy = .creating(
                    try .manual(72.0, at: "2026-09-25T07:12:00+09:00", in: "Asia/Tokyo"),
                    ageSeconds: 10)
                store = .ok(
                    pendingWrites: [legacy, rejectedLegacy], pendingEntries: [registered],
                    recordKinds: [RecordKindMock.ok()])
                transport = .sync(rejectedWriteIndexes: [2])
                engine = .fixture(store: store, transport: transport)
            }

            @Test("登録簿の種類は種類が、無い種類は今の道で、送る書き込みにすること")
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

            @Test("巻き戻しは、登録簿に無い種類の受け付けなかった書き込みにだけ行うこと")
            func revertsOnlyLegacy() async throws {
                let result = try await engine.sync()

                #expect(result.rejectedWrites.map(\.writeId) == [rejectedLegacy.writeId])
                #expect(store.records[legacy.operation.recordId] == nil)
            }
        }

        @Suite("登録簿の種類の書き込みを作れないとき")
        struct BuildingWriteFailing {
            let engine: SyncEngine

            init() {
                engine = .fixture(
                    store: .ok(
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

        @Suite("登録簿にある種類と無い種類の変更を取りに行くとき")
        struct Pulling {
            let store: SyncStoreMock
            let engine: SyncEngine

            init() {
                store = .ok(recordKinds: [RecordKindMock.ok()])
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          {"sequence":1,"kind":"note","recordId":"n1","record":{}},
                          {"sequence":2,"kind":"weight_record","recordId":"00000000-0000-4000-8000-0000000000b1",
                            "record":{"id":"00000000-0000-4000-8000-0000000000b1","weightKg":72.4,
                              "measuredAt":1767225600000,"timeZone":"Asia/Tokyo","version":1}},
                          {"sequence":3,"kind":"note","recordId":"n2","record":{}}
                        ],"hasMore":false,"nextAfterSequence":3,"startedOn":null}
                        """
                    ])
                )
            }

            @Test("登録簿の種類の変更を、種類の名前ごとに1つの結果で箱に渡すこと")
            func handsOwnedChangesToBox() async throws {
                _ = try await engine.sync()

                #expect(
                    store.appliedKindChanges == [
                        KindChanges(
                            kind: "note",
                            changes: [.unknown(kind: "note"), .unknown(kind: "note")])
                    ])
            }

            @Test("無い種類の変更は今の道で当て、通し番号を同じ結果で進めること")
            func appliesRestByLegacyPath() async throws {
                _ = try await engine.sync()

                #expect(store.records.count == 1)
                #expect(store.appliedChanges.map(\.state.afterSequence) == [3])
            }
        }
    }
}

extension PendingWrite.Operation {
    fileprivate var recordId: UUID {
        switch self {
        case .createWeightRecord(let record), .correctWeightRecord(let record, previous: _):
            record.id
        case .sourceDeletedWeightRecord(let recordId): recordId
        case .updateAccountSettings(let settings): settings.id
        }
    }
}
