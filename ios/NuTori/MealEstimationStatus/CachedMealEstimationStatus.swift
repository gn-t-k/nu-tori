import Foundation
import NuToriCore
import SwiftData

/// 食事の推定の状態。食事とは別の種類で、食事より先に届くこともあるので、食事の ID を値で持つ
@Model
nonisolated final class CachedMealEstimationStatus {
    @Attribute(.unique) var mealId: UUID
    var status: String

    init(_ record: MealEstimationStatusSyncing.Status) {
        mealId = record.mealId
        status = Self.stored(record.status)
    }

    func apply(_ record: MealEstimationStatusSyncing.Status) {
        status = Self.stored(record.status)
    }

    func estimationStatus() -> MealEstimationStatus? {
        switch status {
        case "awaiting_photos": .awaitingPhotos
        case "estimating": .estimating
        case "estimated": .estimated
        case "no_dishes": .noDishes
        case "deferred_to_next_day": .deferredToNextDay
        case "awaiting_subscription": .awaitingSubscription
        case "failed": .failed
        // swiftlint:disable:next no_default_in_switch - 置き場の文字列は、知らない値を読めないとみなす
        default: nil
        }
    }

    private static func stored(_ status: MealEstimationStatus) -> String {
        switch status {
        case .awaitingPhotos: "awaiting_photos"
        case .estimating: "estimating"
        case .estimated: "estimated"
        case .noDishes: "no_dishes"
        case .deferredToNextDay: "deferred_to_next_day"
        case .awaitingSubscription: "awaiting_subscription"
        case .failed: "failed"
        }
    }
}
