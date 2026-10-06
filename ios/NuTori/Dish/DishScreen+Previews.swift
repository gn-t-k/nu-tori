#if DEBUG
    import Foundation
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: DishScreen.Sample.allCases) { sample in
        NavigationStack {
            DishScreen(
                contents: sample.contents,
                removal: .dish(dishId: sample.contents.dish.id),
                actions: .noop,
                deleteMeal: {})
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

            var contents: DishContents {
                let meal = MealCard.sampleEstimated(.sample(on: .sampleToday, at: 12, 10))
                let oyakodon = meal.contents.dishes[0]
                let dish = oyakodon.dish
                switch self {
                case .estimated:
                    return oyakodon
                case .quantityCorrected:
                    return DishContents(
                        dish: Dish(
                            id: dish.id, mealId: dish.mealId, name: dish.name,
                            quantity: Dish.Quantity(value: 1.5, unit: "杯", source: .corrected),
                            positionInMeal: 0, version: 2),
                        ingredients: oyakodon.ingredients)
                case .estimating:
                    return DishContents(
                        dish: dish, ingredients: oyakodon.ingredients, progress: .estimating)
                case .deferredToNextDay:
                    return DishContents(
                        dish: dish, ingredients: oyakodon.ingredients,
                        progress: .deferredToNextDay)
                case .unestimable:
                    return DishContents(dish: dish, ingredients: [], progress: .unestimable)
                case .added:
                    return DishContents(
                        dish: Dish(
                            id: UUID(), mealId: dish.mealId, name: "サラダ", quantity: nil,
                            positionInMeal: 2, version: 1),
                        ingredients: [], progress: .notSent)
                }
            }
        }
    }
#endif
