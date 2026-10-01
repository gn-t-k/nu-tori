import Foundation
import NuToriCore
import SwiftData

/// 食事の推定の状態。食事とは別の種類で、食事より先に届くこともあるので、食事の ID を値で持つ
@Model
nonisolated final class CachedMealEstimationStatus {
    @Attribute(.unique) var mealId: UUID
    var status: String

    init(mealId: UUID, status: MealEstimationStatus) {
        self.mealId = mealId
        self.status = Self.stored(status)
    }

    func apply(_ status: MealEstimationStatus) {
        self.status = Self.stored(status)
    }

    func estimationStatus() -> MealEstimationStatus? {
        switch status {
        case "awaiting_photos": .awaitingPhotos
        case "estimating": .estimating
        case "estimated": .estimated
        case "no_dishes": .noDishes
        case "deferred_to_next_day": .deferredToNextDay
        case "failed": .failed
        default: nil
        }
    }

    /// 保存は呼び出し側が行う
    static func write(
        _ status: MealEstimationStatus, forMealId mealId: UUID, in context: ModelContext
    ) throws {
        if let existing = try find(mealId: mealId, in: context) {
            existing.apply(status)
        } else {
            context.insert(CachedMealEstimationStatus(mealId: mealId, status: status))
        }
    }

    static func find(mealId: UUID, in context: ModelContext) throws -> CachedMealEstimationStatus? {
        var descriptor = FetchDescriptor<CachedMealEstimationStatus>(
            predicate: #Predicate { $0.mealId == mealId })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func stored(_ status: MealEstimationStatus) -> String {
        switch status {
        case .awaitingPhotos: "awaiting_photos"
        case .estimating: "estimating"
        case .estimated: "estimated"
        case .noDishes: "no_dishes"
        case .deferredToNextDay: "deferred_to_next_day"
        case .failed: "failed"
        }
    }
}
