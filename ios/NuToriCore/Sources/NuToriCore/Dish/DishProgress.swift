/// 料理ごとの待ちの見え方。料理ごとの推定の状態に、送った端末の「まだ送れていない」と、食事の推定が済んでいるかを足したもの
public enum DishProgress: Hashable, Sendable {
    /// 待っていない（推定し直しをしていない）か、推定できた
    case settled
    /// 送った端末で、料理を足す・名前を直す書き込みがまだ送れていない、または料理ごとの推定の状態がまだ届いていない
    case notSent
    case estimating
    case deferredToNextDay
    /// 推定し直しが通らなかった（料理なし・推定できなかった）。名前と前の量を残し、0 kcal にする
    case unestimable

    /// `unsent` は、送り待ちにその料理を足す・名前を直す書き込みがあるか。`mealState` は、その食事のカードの状態
    init(dish: Dish, status: DishEstimationStatus?, unsent: Bool, mealState: MealCardState) {
        if unsent {
            self = .notSent
            return
        }
        switch status {
        case nil:
            // 量の無い料理は、足したばかりで状態がまだ届いていない料理。写真の推定が済んでいない食事の状態の無い料理は、
            // 写真の推定が作った料理が食事の状態より先に届いたもので、食事の状態が届くまで分からない料理として扱う
            self =
                dish.quantity == nil || mealState.awaitsPhotoEstimation
                ? .notSent : .settled
        case .estimated: self = .settled
        case .estimating: self = .estimating
        case .deferredToNextDay: self = .deferredToNextDay
        case .noDishes, .failed: self = .unestimable
        }
    }

    /// 量と材料が届くのを待っているか。待っている料理は、合計に足さず「以上」を付ける
    public var isWaiting: Bool {
        switch self {
        case .notSent, .estimating, .deferredToNextDay: true
        case .settled, .unestimable: false
        }
    }
}
