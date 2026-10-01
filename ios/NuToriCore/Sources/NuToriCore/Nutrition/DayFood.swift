/// 1日の食べた量。1日の丸と日のまとめに出す値で、その日に入れる食事（食事の日がその日の食事）から出す。
/// 目標が無いあいだは、丸は P・F・C の割合で一周する
public enum DayFood: Hashable, Sendable {
    /// 食事の無い日。「食事と栄養」のまとまりを出さない
    case noMeals
    /// 食事はあるが、どれも推定が済んでいない（まだ送れていない、写真を待っている、推定中、翌日に推定。状態で書き分けない）。
    /// 丸の中と P・F・C は「—」で、「この日の食事は、まだ料理と栄養を推定しているところです。…」を添える
    case allPending
    /// 済んだ食事から kcal が出ない（済んだのは料理なし・推定できなかった食事だけ）。丸の中と P・F・C は「—」で、
    /// 済んでいない食事が無ければ「この日の食事からは、kcal と P・F・C を出せませんでした。」、
    /// あれば「まだ推定が済んでいない食事が N つあります。…」を添える
    case unavailable(pendingMealCount: Int)
    /// 推定が済んだ食事の kcal がある
    case figures(Figures)

    /// 推定が済んだ食事の合計
    public struct Figures: Hashable, Sendable {
        /// 済んだ食事の栄養の合計。「不明」の材料が混じる栄養は「以上」になる
        public let totals: NutrientTotals
        /// 丸の P・F・C の割合。P・F・C がすべて 0 のときは nil（丸は空の輪にして、中に kcal を書く）
        public let shares: PFCShares?
        /// 推定が済んでいない食事の数。0 でなければ、「まだ推定が済んでいない食事が N つあります。…」を添える
        public let pendingMealCount: Int
    }

    /// `meals` は、その日に入れる食事のカード（食事の日がその日で、使い始めた日以降のもの）
    public init(meals: [MealCard]) {
        if meals.isEmpty {
            self = .noMeals
            return
        }
        var estimatedTotals: [NutrientTotals] = []
        var pendingMealCount = 0
        for meal in meals {
            switch meal.nutrition {
            case .estimated(let totals): estimatedTotals.append(totals)
            case .pending: pendingMealCount += 1
            case .noFood: break
            }
        }
        let totals = NutrientTotals(combining: estimatedTotals)
        if !estimatedTotals.isEmpty, totals[.energyKcal].value != nil {
            self = .figures(
                Figures(
                    totals: totals, shares: PFCShares(totals: totals),
                    pendingMealCount: pendingMealCount))
        } else if pendingMealCount == meals.count {
            self = .allPending
        } else {
            self = .unavailable(pendingMealCount: pendingMealCount)
        }
    }

    public var figures: Figures? {
        if case .figures(let figures) = self { figures } else { nil }
    }

    /// 日のまとめの「食事と栄養」の下に添える文。食事の無い日はまとまりを出さないので空
    public var notes: [String] {
        let ring = "目標がないので、丸は P・F・C の割合で一周します。"
        switch self {
        case .noMeals:
            return []
        case .allPending:
            return [
                ring,
                "この日の食事は、まだ料理と栄養を推定しているところです。推定が済むと、ここに kcal と P・F・C が出ます。",
            ]
        case .unavailable(let pendingMealCount):
            return [
                ring,
                Self.pendingNote(pendingMealCount)
                    ?? "この日の食事からは、kcal と P・F・C を出せませんでした。",
            ]
        case .figures(let figures):
            return [ring] + [Self.pendingNote(figures.pendingMealCount)].compactMap(\.self)
        }
    }

    /// 推定が済んでいない食事があるときの文。無ければ nil
    private static func pendingNote(_ pendingMealCount: Int) -> String? {
        guard pendingMealCount > 0 else { return nil }
        return
            "まだ推定が済んでいない食事が\(pendingMealCount)つあります。推定が済むと、その食事の kcal と P・F・C も、この合計に足されます。"
    }
}
