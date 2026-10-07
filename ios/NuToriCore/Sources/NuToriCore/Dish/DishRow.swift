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
        let shown = contents.shownQuantity
        quantity = shown.map { NutritionText.quantity($0.value, unit: $0.unit) } ?? "—"
        showsEstimateBadge = shown?.source == .estimated
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
