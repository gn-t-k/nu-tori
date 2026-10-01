import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("体重記録の同期")
    struct WeightRecordKind {
        @Suite("受け付けなかった書き込みを送ったとき")
        struct Pushing {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine
            let created: WeightRecord
            let serverRecord: WeightRecord
            let corrected: WeightRecord

            init() throws {
                created = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                serverRecord = try .manual(70.0, at: "2026-09-23T07:12:00+09:00", in: "Asia/Tokyo")
                corrected = WeightRecord(
                    id: serverRecord.id, kilograms: 71.0, instant: serverRecord.instant,
                    timeZone: serverRecord.timeZone, inputSource: .manual, version: 2)
                store = try .ok(
                    records: [created, corrected],
                    pendingWrites: [
                        .creating(created, ageSeconds: 20),
                        .correcting(corrected),
                    ])
                engine = .fixture(
                    store: store,
                    transport: .sync(
                        rejectedWriteIndexes: [0, 1],
                        currents: [0: .absent, 1: .weightRecord(serverRecord)]))
            }

            @Test("受け付けなかった行を返し、サーバーに無い記録は消し、値がある記録はその値に合わせること")
            func revertsWeightRecords() async throws {
                let result = try await engine.sync()

                #expect(
                    result.rejectedWrites.map(\.record) == [
                        .weightRecord(created, serverHasValue: false),
                        .weightRecord(corrected, serverHasValue: true),
                    ])
                #expect(store.records[created.id] == nil)
                #expect(store.records[serverRecord.id] == serverRecord)
                #expect(store.entries.isEmpty)
            }
        }

        @Suite("体重記録の変更を取りに行ったとき")
        struct Pulling {
            let store: SyncBoxMock<RecordCacheMock>
            let export: WeightHealthExportMock
            let engine: SyncEngine
            let revisedId: UUID

            init() throws {
                revisedId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000b1"))
                export = .ok()
                store = try .ok(
                    records: [
                        try .manual(
                            70.0, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo", id: revisedId)
                    ])
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          {"sequence":1,"kind":"weight_record","recordId":"\(revisedId.uuidString)",
                            "record":{"id":"\(revisedId.uuidString)","weightKg":73.1,
                              "measuredAt":1767225600000,"timeZone":"Asia/Tokyo","version":4}},
                          {"sequence":2,"kind":"weight_record_deletion",
                            "recordId":"00000000-0000-4000-8000-0000000000b9","record":{}}
                        ],"hasMore":false,"nextAfterSequence":2,"startedOn":null}
                        """
                    ]),
                    weightHealthExport: export)
            }

            @Test("体重記録の変更を、種類の名前ごとに、通し番号と同じ結果で箱に渡すこと")
            func handsChangesToBox() async throws {
                _ = try await engine.sync()

                #expect(store.appliedKindChanges.map(\.kind) == [.weightRecord])
                #expect(store.appliedKindChanges.first?.changes.count == 2)
                #expect(store.appliedSyncStates.map(\.afterSequence) == [2])
            }

            @Test("版が上がった手の記録を、ヘルスケアに書き直すこと")
            func exportsRevisedManualRecord() async throws {
                _ = try await engine.sync()

                #expect(export.writes.map(\.id) == [revisedId])
                #expect(export.writes.map(\.version) == [4])
            }
        }
    }
}
