public import Foundation

/// 食事の推定の状態。サーバーだけが書く。記録の ID は食事の ID
public struct SyncedMealEstimationStatus: Sendable, Equatable {
    public let mealId: UUID
    public let status: Status

    public init(mealId: UUID, status: Status) {
        self.mealId = mealId
        self.status = status
    }

    /// サーバーの `status` の値
    public enum Status: String, Sendable, Equatable {
        case awaitingPhotos = "awaiting_photos"
        case estimating
        case estimated
        case noDishes = "no_dishes"
        case deferredToNextDay = "deferred_to_next_day"
        case failed
    }
}
