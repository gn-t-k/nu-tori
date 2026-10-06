import Foundation
import NuToriCore
import SwiftData

/// 料理ごとの推定の状態。料理とは別の種類で、料理より先に届くこともあるので、料理の ID を値で持つ
@Model
nonisolated final class CachedDishEstimationStatus {
    @Attribute(.unique) var dishId: UUID
    var status: String

    init(dishId: UUID, status: DishEstimationStatus) {
        self.dishId = dishId
        self.status = Self.stored(status)
    }

    func apply(_ status: DishEstimationStatus) {
        self.status = Self.stored(status)
    }

    func estimationStatus() -> DishEstimationStatus? {
        switch status {
        case "estimating": .estimating
        case "deferred_to_next_day": .deferredToNextDay
        case "estimated": .estimated
        case "no_dishes": .noDishes
        case "failed": .failed
        default: nil
        }
    }

    /// 保存は呼び出し側が行う
    static func write(
        _ status: DishEstimationStatus, forDishId dishId: UUID, in context: ModelContext
    ) throws {
        if let existing = try find(dishId: dishId, in: context) {
            existing.apply(status)
        } else {
            context.insert(CachedDishEstimationStatus(dishId: dishId, status: status))
        }
    }

    static func find(dishId: UUID, in context: ModelContext) throws -> CachedDishEstimationStatus? {
        var descriptor = FetchDescriptor<CachedDishEstimationStatus>(
            predicate: #Predicate { $0.dishId == dishId })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func stored(_ status: DishEstimationStatus) -> String {
        switch status {
        case .estimating: "estimating"
        case .deferredToNextDay: "deferred_to_next_day"
        case .estimated: "estimated"
        case .noDishes: "no_dishes"
        case .failed: "failed"
        }
    }
}
