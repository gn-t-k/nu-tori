public import Foundation

/// 推定の結果を待っている食事と、結果が出た食事。待っていた食事の結果が出た瞬間に触覚で知らせる合図にする（#325）。
/// どの判定も、前に持っていなかった食事（開いたときに最初から結果が出ていた、ほかの端末から結果が出て届いた）では合図にしない
public struct MealEstimationProgress: Equatable, Sendable {
    public init(meals: [MealCard]) {
        waiting = ids(of: meals, where: \.isAwaitingEstimateNow)
        estimated = ids(of: meals) { $0 == .estimated }
        failed = ids(of: meals) { $0 == .failed }
        withoutDishes = ids(of: meals) { $0 == .noDishes }
    }

    /// 前に待っていた食事のうち、推定できたものがあるか。いくつ済んでも1回の合図にする
    public func hasFinished(since earlier: MealEstimationProgress) -> Bool {
        !earlier.waiting.isDisjoint(with: estimated)
    }

    /// 前に待っていた食事のうち、推定できなかったものがあるか
    public func hasFailed(since earlier: MealEstimationProgress) -> Bool {
        !earlier.waiting.isDisjoint(with: failed)
    }

    /// 前に待っていた食事のうち、写真に料理が見つからなかったものがあるか
    public func hasFoundNoDishes(since earlier: MealEstimationProgress) -> Bool {
        !earlier.waiting.isDisjoint(with: withoutDishes)
    }

    private let waiting: Set<UUID>
    private let estimated: Set<UUID>
    private let failed: Set<UUID>
    private let withoutDishes: Set<UUID>
}

private func ids(of meals: [MealCard], where matches: (MealCardState) -> Bool) -> Set<UUID> {
    Set(meals.filter { matches($0.state) }.map(\.meal.id))
}
