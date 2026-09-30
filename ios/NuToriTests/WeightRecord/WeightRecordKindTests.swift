import Foundation
import NuToriAPI
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("体重記録の種類")
struct WeightRecordKindTests {
    static func syncedRecord(id: UUID, kilograms: Double, version: Int) -> SyncedWeightRecord {
        SyncedWeightRecord(
            id: id, weightKilograms: kilograms,
            measuredAt: Date(timeIntervalSince1970: 1_700_000_000),
            timeZone: TimeZone(identifier: "Asia/Tokyo")!, version: version, imported: nil)
    }

    @Suite("取りに行った変更をキャッシュに当てるとき")
    @MainActor
    struct Applying {
        let store: SwiftDataSyncStore
        let kept: UUID
        let revised: UUID
        let removed: UUID

        init() async throws {
            store = try SwiftDataSyncStore(inMemory: true)
            kept = UUID(uuidString: "00000000-0000-4000-8000-0000000000a1")!
            revised = UUID(uuidString: "00000000-0000-4000-8000-0000000000a2")!
            removed = UUID(uuidString: "00000000-0000-4000-8000-0000000000a3")!
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(
                        kind: "weight-record",
                        changes: [
                            .weightRecord(syncedRecord(id: kept, kilograms: 70, version: 1)),
                            .weightRecord(syncedRecord(id: revised, kilograms: 71, version: 1)),
                            .weightRecord(syncedRecord(id: removed, kilograms: 72, version: 1)),
                        ])
                ]))
        }

        @Test("届いた記録が今の値でキャッシュに入ること")
        func storesArrivedRecords() async throws {
            #expect(try await store.weightRecord(id: kept)?.kilograms == 70)
            #expect(try await store.weightRecords().count == 3)
        }

        @Test("同じ記録の新しい版が、キャッシュの記録を上書きすること")
        func overwritesRevisedRecord() async throws {
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(
                        kind: "weight-record",
                        changes: [
                            .weightRecord(
                                WeightRecordKindTests.syncedRecord(
                                    id: revised, kilograms: 73, version: 2))
                        ])
                ]))

            let record = try #require(await store.weightRecord(id: revised))
            #expect(record.kilograms == 73)
            #expect(record.version == 2)
            #expect(try await store.weightRecords().count == 3)
        }

        @Test("削除の印の記録が消え、置き場に無い記録の削除の印は読み飛ばすこと")
        func removesMarkedRecordsAndSkipsMissing() async throws {
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(
                        kind: "weight-record",
                        changes: [
                            .weightRecordDeletion(recordId: removed),
                            .weightRecordDeletion(recordId: UUID()),
                        ])
                ]))

            #expect(try await store.weightRecord(id: removed) == nil)
            #expect(try await store.weightRecords().count == 2)
        }

        @Test("全消去で、体重記録がキャッシュから無くなること")
        func erasesWithEverythingElse() async throws {
            try await store.eraseAll()

            #expect(try await store.weightRecords().isEmpty)
        }
    }
}
