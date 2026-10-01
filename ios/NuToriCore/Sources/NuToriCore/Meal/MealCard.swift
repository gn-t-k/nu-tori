/// タイムラインに置く食事のカード。食事と、カードに見せる状態を持つ
public struct MealCard: Hashable, Sendable {
    public let meal: Meal
    public let state: MealCardState

    /// `status` はキャッシュの推定の状態で、まだ届いていなければ nil。
    /// `recordedOnThisDevice` は、この端末で記録した（送った端末の）食事か
    public init(meal: Meal, status: MealEstimationStatus?, recordedOnThisDevice: Bool) {
        self.meal = meal
        state = MealCardState(status: status, recordedOnThisDevice: recordedOnThisDevice)
    }
}
