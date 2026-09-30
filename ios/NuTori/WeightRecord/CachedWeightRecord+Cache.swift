import Foundation
import NuToriCore
import SwiftData

/// キャッシュの体重記録の読み書き。登録簿の種類（`WeightRecordKind`）と、今の道の口（`SwiftDataSyncStore`）が使う。
/// 保存は呼び出し側が行う
extension CachedWeightRecord {
    nonisolated static func find(id: UUID, in context: ModelContext) throws -> CachedWeightRecord? {
        var descriptor = FetchDescriptor<CachedWeightRecord>(
            predicate: #Predicate { $0.recordId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func upsert(_ record: WeightRecord, in context: ModelContext) throws {
        if let existing = try find(id: record.id, in: context) {
            try existing.apply(record)
        } else {
            context.insert(try CachedWeightRecord(record))
        }
    }
}
