#if DEBUG
    import Foundation
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: DishScreen.Sample.allCases) { sample in
        // 見本の料理の ID は作るたびに変わるので、料理と受け付けなかった1行は同じカードから作る
        let card = MealCard.sampleEstimated(.sample(on: .sampleToday, at: 12, 10))
        let contents = sample.contents(in: card)
        NavigationStack {
            DishScreen(
                contents: contents,
                list: DishScreenList(
                    contents: contents, in: card,
                    rejectedLines: sample.rejectedLines(of: contents, in: card)),
                removal: sample.removal(of: contents),
                actions: .noop,
                deleteMeal: {},
                confirmsMealDeletion: sample.confirmsMealDeletion)
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
            /// 食事の最後の1品で「この料理を削除」を押し、食事ごと消すかを画面の下から確かめている
            case confirmingMealDeletion

            func contents(in card: MealCard) -> DishContents {
                let oyakodon = card.contents.dishes[0]
                let dish = oyakodon.dish
                switch self {
                case .estimated, .rejectedQuantity, .confirmingMealDeletion:
                    return oyakodon
                case .quantityCorrected:
                    return DishContents(
                        dish: Dish(
                            id: dish.id, mealId: dish.mealId, name: dish.name,
                            quantity: Dish.Quantity(value: 1.5, unit: "杯", source: .corrected),
                            positionInMeal: 0, version: 2),
                        ingredients: oyakodon.ingredients, progress: .settled)
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

            /// 最後の1品の見本だけ、料理を消すと食事の料理が無くなる
            func removal(of contents: DishContents) -> DishRemoval {
                self == .confirmingMealDeletion
                    ? .meal(mealId: contents.dish.mealId) : .dish(dishId: contents.dish.id)
            }

            var confirmsMealDeletion: Bool { self == .confirmingMealDeletion }

            /// 量を「1.5杯」に直そうとして、受け付けられなかった
            func rejectedLines(of contents: DishContents, in card: MealCard) -> [RejectedLine] {
                guard self == .rejectedQuantity else { return [] }
                let dish = contents.dish
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
