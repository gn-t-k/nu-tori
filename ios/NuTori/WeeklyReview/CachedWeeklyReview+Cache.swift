import Foundation
import NuToriCore
import SwiftData

/// キャッシュの週の見直しの行の引き方と、記録との行き来。SwiftData の adapter（`SwiftDataKeyedRecordCache`）が使う。
/// 保存は呼び出し側が行う
extension CachedWeeklyReview: KeyedCacheRow {
    nonisolated static func id(of record: WeeklyReview) -> UUID {
        record.id
    }

    nonisolated static func find(id: UUID, in context: ModelContext) throws -> CachedWeeklyReview? {
        var descriptor = FetchDescriptor<CachedWeeklyReview>(
            predicate: #Predicate { $0.reviewId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated func record() -> WeeklyReview? {
        weeklyReview()
    }
}
