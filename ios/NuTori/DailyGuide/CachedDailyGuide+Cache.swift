import Foundation
import NuToriCore
import SwiftData

/// キャッシュの1日の目安の行の引き方と、記録との行き来。SwiftData の adapter（`SwiftDataKeyedRecordCache`）が使う。
/// 保存は呼び出し側が行う
extension CachedDailyGuide: KeyedCacheRow {
    nonisolated static func id(of record: DailyGuide) -> UUID {
        record.id
    }

    nonisolated static func find(id: UUID, in context: ModelContext) throws -> CachedDailyGuide? {
        var descriptor = FetchDescriptor<CachedDailyGuide>(
            predicate: #Predicate { $0.guideId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated func record() -> DailyGuide? {
        dailyGuide()
    }
}
