/// 料理ごとの待ちの見え方。料理ごとの推定の状態に、送った端末の「まだ送れていない」と、食事が写真を待っているかを足したもの
public enum DishProgress: Hashable, Sendable {
    /// 待っていない（推定し直しをしていない）か、推定できた
    case settled
    /// 送った端末で、料理を足す・名前を直す書き込みがまだ送れていない、または料理ごとの推定の状態がまだ届いていない。
    /// 食事が写真を待っているあいだの推定中の料理も、これと同じに見せる（サーバーは写真を待っていて処理していないため）
    case notSent
    case estimating
    case deferredToNextDay
    /// 推定し直しが通らなかった（料理なし・推定できなかった）。名前と前の量を残し、0 kcal にする
    case unestimable

    /// `unsent` は、送り待ちにその料理を足す・名前を直す書き込みがあるか。`mealState` は、その食事のカードの状態（無ければ推定できた食事として扱う）
    init(dish: Dish, status: DishEstimationStatus?, unsent: Bool, mealState: MealCardState?) {
        if unsent {
            self = .notSent
            return
        }
        switch status {
        case nil:
            // 量の無い料理は、足したばかりで状態がまだ届いていない料理。写真の推定が済んでいない食事の状態の無い料理は、
            // 写真の推定が作った料理が食事の状態より先に届いたもので、食事の状態が届くまで分からない料理として扱う
            self =
                dish.quantity == nil || mealState?.awaitsPhotoEstimation == true
                ? .notSent : .settled
        case .estimated: self = .settled
        case .estimating:
            // 食事が写真を待っているあいだは、サーバーは料理の推定も始めていない
            self = mealState == .notSent || mealState == .awaitingPhotos ? .notSent : .estimating
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

/// 食事の画面の料理の行に出すもの（名前の右の量・推定の印・kcal と、行の下の1行）。料理の画面の名前の下の1行も同じ
public struct DishRow: Hashable, Sendable {
    /// 「1杯」。待っている料理は、量を直してあれば直した量、なければ「—」
    public let quantity: String
    /// 量の出どころが推定したままの量に添える
    public let showsEstimateBadge: Bool
    /// 「40 kcal」。待っている料理は「—」、通らなかった料理は 0 kcal
    public let kilocalories: String
    /// 行の下の1行。待っていない料理とまだ送れていない料理は nil（`DESIGN.md` の Don'ts）
    public let note: Note?

    init(contents: DishContents) {
        let quantity = contents.dish.quantity
        switch contents.progress {
        case .settled, .unestimable:
            self.quantity =
                quantity.map { NutritionText.quantity($0.value, unit: $0.unit) } ?? "—"
            showsEstimateBadge = quantity?.source == .estimated
        case .notSent, .estimating, .deferredToNextDay:
            let corrected = quantity.flatMap { $0.source == .corrected ? $0 : nil }
            self.quantity =
                corrected.map { NutritionText.quantity($0.value, unit: $0.unit) } ?? "—"
            showsEstimateBadge = false
        }
        switch contents.progress {
        case .settled:
            kilocalories = NutritionText.amount(contents.totals[.energyKcal], of: .energyKcal)
            note = nil
        case .notSent:
            kilocalories = "—"
            note = nil
        case .estimating:
            kilocalories = "—"
            note = .estimating
        case .deferredToNextDay:
            kilocalories = "—"
            note = .deferredToNextDay
        case .unestimable:
            kilocalories = NutritionText.amount(.exactly(0), of: .energyKcal)
            note = .unestimable
        }
    }

    public enum Note: Hashable, Sendable {
        case estimating
        case deferredToNextDay
        case unestimable

        public var text: String {
            switch self {
            case .estimating: "推定しています…"
            // 回数の上限の数は書かない
            case .deferredToNextDay: "今日はもう推定できないため、明日推定します"
            case .unestimable: "この名前からは材料を推定できませんでした"
            }
        }

        /// 推定の待っている表示。サーバーが実際に処理しているあいだだけ出す
        public var showsSpinner: Bool { self == .estimating }
    }
}
