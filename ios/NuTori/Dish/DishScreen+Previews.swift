#if DEBUG
    import Foundation
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: DishScreen.Sample.allCases) { sample in
        // 見本の料理の ID は作るたびに変わるので、見本のカードと受け付けなかった1行は同じ食事から作る
        let base = MealCard.sampleEstimated(.sample(on: .sampleToday, at: 12, 10))
        let shown = sample.shownDish(in: base)
        let offer = MealEditOffer(card: sample.card(from: base, shown: shown)).dishScreen(
            dishId: shown.id, rejectedLines: sample.rejectedLines(of: shown, in: base))
        NavigationStack {
            if let offer {
                DishScreen(
                    offer: offer,
                    actions: .noop,
                    deleteMeal: {},
                    confirmsMealDeletion: sample.confirmsMealDeletion)
            }
        }
    }

    extension DishScreen {
        fileprivate enum Sample: CaseIterable {
            /// 推定できた親子丼。量に推定の印、材料と主な栄養・ミネラル・ビタミン。割り下は推定の材料で、ミネラルとビタミンは「不明」か「以上」
            case estimated
            /// 料理の量を直した。推定の印が外れる
            case quantityCorrected
            /// 名前を直して推定し直している。量は「—」、名前の下に回る印と「推定しています…」。材料と栄養は出さない
            case estimating
            /// その日の回数を使い切ったので、明日推定する
            case deferredToNextDay
            /// 名前から材料を推定できなかった。前の量を残す
            case unestimable
            /// 足したばかりで、まだ送れていない。量の欄は無い
            case added
            /// 料理の量を直す書き込みを受け付けられず、名前と量の下に「直せなかった」1行を出している
            case rejectedQuantity
            /// 食事の最後の1品で「この料理を削除」を押し、食事ごと消すかを押したボタンから確かめている
            case confirmingMealDeletion

            /// 画面に出す料理。足したばかりの見本だけ、見本のカードに無いサラダを足す
            func shownDish(in base: MealCard) -> Dish {
                let oyakodon = base.contents.dishes[0].dish
                switch self {
                case .estimated, .estimating, .deferredToNextDay, .unestimable, .rejectedQuantity,
                    .confirmingMealDeletion:
                    return oyakodon
                case .quantityCorrected:
                    return Dish(
                        id: oyakodon.id, mealId: oyakodon.mealId, name: oyakodon.name,
                        quantity: Dish.Quantity(value: 1.5, unit: "杯", source: .corrected),
                        positionInMeal: 0, version: 2)
                case .added:
                    return Dish(
                        id: UUID(), mealId: oyakodon.mealId, name: "サラダ", quantity: nil,
                        positionInMeal: 2, version: 1)
                }
            }

            /// 見本のカード（推定できた親子丼と味噌汁）の、`shown` の料理をこの見本の状態にしたカード
            func card(from base: MealCard, shown: Dish) -> MealCard {
                let others = base.contents.dishes.filter { $0.dish.id != shown.id }
                // 最後の1品の見本だけ、ほかの料理を外す
                let kept = self == .confirmingMealDeletion ? [] : others
                let shownIngredients =
                    base.contents.dishes.first { $0.dish.id == shown.id }?.ingredients ?? []
                return MealCard(
                    meal: base.meal, status: .estimated, recordedOnThisDevice: true,
                    dishes: [shown] + kept.map(\.dish),
                    ingredients: (self == .unestimable ? [] : shownIngredients)
                        + kept.flatMap(\.ingredients),
                    dishEstimationStatuses: dishEstimationStatus.map { [shown.id: $0] } ?? [:],
                    unsentDishIds: self == .added ? [shown.id] : [])
            }

            private var dishEstimationStatus: DishEstimationStatus? {
                switch self {
                case .estimated, .quantityCorrected, .added, .rejectedQuantity,
                    .confirmingMealDeletion:
                    nil
                case .estimating: .estimating
                case .deferredToNextDay: .deferredToNextDay
                case .unestimable: .noDishes
                }
            }

            var confirmsMealDeletion: Bool { self == .confirmingMealDeletion }

            /// 量を「1.5杯」に直そうとして、受け付けられなかった
            func rejectedLines(of dish: Dish, in card: MealCard) -> [RejectedLine] {
                guard self == .rejectedQuantity else { return [] }
                return [
                    .meal(
                        RejectedMealLine(
                            meal: card.meal,
                            subject: .dishQuantity(
                                RejectedMealLine.DishPlace(
                                    id: dish.id, name: dish.name,
                                    positionInMeal: dish.positionInMeal),
                                attempted: 1.5, unit: "杯")))
                ]
            }
        }
    }
#endif
