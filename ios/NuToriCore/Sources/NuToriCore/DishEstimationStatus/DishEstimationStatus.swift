/// サーバーが推定の出来事から出す、料理ごとの推定の状態。サーバーだけが書き、同期で届く。
/// 推定し直しをしていない料理（食事の推定で作り、名前を直していない料理）は持たない
public enum DishEstimationStatus: Hashable, Sendable {
    case estimating
    case deferredToNextDay
    case estimated
    case noDishes
    case failed
}
