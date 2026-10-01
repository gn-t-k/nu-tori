/// サーバーが推定の出来事から出す、食事の推定の状態。サーバーだけが書き、同期で届く
public enum MealEstimationStatus: Hashable, Sendable {
    case awaitingPhotos
    case estimating
    case estimated
    case noDishes
    case deferredToNextDay
    case failed
}
