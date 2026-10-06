public import Foundation

/// 料理ごとの推定の状態。サーバーだけが書く。記録の ID は料理の ID。推定し直しをしていない料理は持たない
public struct SyncedDishEstimationStatus: Sendable, Equatable {
    public let dishId: UUID
    public let status: Status

    public init(dishId: UUID, status: Status) {
        self.dishId = dishId
        self.status = status
    }

    /// サーバーの `status` の値。食事の推定の状態から「写真を待っている」を除いたもの
    public enum Status: String, Sendable, Equatable {
        case estimating
        case deferredToNextDay = "deferred_to_next_day"
        case estimated
        case noDishes = "no_dishes"
        case failed
    }
}
