import Foundation
import NuToriCore
import SwiftData

/// キャッシュの目標の行の引き方と、記録との行き来。SwiftData の adapter（`SwiftDataKeyedRecordCache`）が使う。
/// 保存は呼び出し側が行う
extension CachedGoal: KeyedCacheRow {
    nonisolated static func id(of record: Goal) -> UUID {
        record.id
    }

    nonisolated static func find(id: UUID, in context: ModelContext) throws -> CachedGoal? {
        var descriptor = FetchDescriptor<CachedGoal>(predicate: #Predicate { $0.goalId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated func record() -> Goal? {
        goal()
    }
}
