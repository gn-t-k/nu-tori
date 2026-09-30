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
            let store: MemoryStore
            let engine: SyncEngine
            let created: WeightRecord
            let previous: WeightRecord
            let corrected: WeightRecord

            init() throws {
                created = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                previous = try .manual(70.0, at: "2026-09-23T07:12:00+09:00", in: "Asia/Tokyo")
                corrected = WeightRecord(
                    id: previous.id, kilograms: 71.0, instant: previous.instant,
                    timeZone: previous.timeZone, inputSource: .manual, version: 2)
                store = .ok(
                    records: [created, corrected],
                    pendingWrites: [
                        .creating(created, ageSeconds: 20),
                        .correcting(corrected, previous: previous),
                    ])
                engine = .fixture(store: store, transport: .sync(rejectedWriteIndexes: [0, 1]))
            }

            @Test("受け付けなかった行を返し、作った記録は消し、直した記録は直す前に戻すこと")
            func revertsWeightRecords() async throws {
                let result = try await engine.sync()

                #expect(result.rejectedWrites.map(\.record.id) == [created.id, previous.id])
                #expect(store.records[created.id] == nil)
                #expect(store.records[previous.id] == previous)
                #expect(store.entries.isEmpty)
            }
        }

        @Suite("体重記録の変更を取りに行ったとき")
        struct Pulling {
            let store: MemoryStore
            let export: WeightHealthExportMock
            let engine: SyncEngine
            let revisedId: UUID

            init() throws {
                revisedId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000b1"))
                export = .ok()
                store = .ok(
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

                #expect(store.appliedKindChanges.map(\.kind) == ["weight-record"])
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
