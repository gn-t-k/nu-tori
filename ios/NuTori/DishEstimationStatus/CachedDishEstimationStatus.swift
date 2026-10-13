import Foundation
import NuToriCore
import SwiftData

/// 料理ごとの推定の状態。料理とは別の種類で、料理より先に届くこともあるので、料理の ID を値で持つ
@Model
nonisolated final class CachedDishEstimationStatus {
    @Attribute(.unique) var dishId: UUID
    var status: String

    init(_ record: DishEstimationStatusSyncing.Status) {
        dishId = record.dishId
        status = Self.stored(record.status)
    }

    func apply(_ record: DishEstimationStatusSyncing.Status) {
        status = Self.stored(record.status)
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
