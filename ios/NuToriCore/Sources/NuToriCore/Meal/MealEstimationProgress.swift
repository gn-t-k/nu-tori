public import Foundation

/// 推定の結果を待っている食事と、推定できた食事。待っていた食事の推定が済んだ瞬間に触覚で知らせる合図にする（#325、基準は DESIGN.md の Motion の「触覚」）
public struct MealEstimationProgress: Equatable, Sendable {
    private let waiting: Set<UUID>
    private let estimated: Set<UUID>

    public init(meals: [MealCard]) {
        waiting = Set(meals.filter(\.state.isAwaitingEstimateNow).map(\.meal.id))
        estimated = Set(meals.filter { $0.state == .estimated }.map(\.meal.id))
    }

    /// 前に待っていた食事のうち、推定できたものがあるか。いくつ済んでも1回の合図にする。
    /// 前に持っていなかった食事（開いたときに最初から済んでいた、ほかの端末から済んで届いた）では合図にしない
    public func hasFinished(since earlier: MealEstimationProgress) -> Bool {
        !earlier.waiting.isDisjoint(with: estimated)
    }
}
