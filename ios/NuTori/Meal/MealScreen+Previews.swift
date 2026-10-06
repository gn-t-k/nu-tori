#if DEBUG
    import Foundation
    import NuToriCore
    import SwiftUI
    import UIKit

    #Preview("状態ごと", arguments: MealScreen.Sample.allCases) { sample in
        NavigationStack {
            MealScreen(
                card: sample.card,
                loadPhoto: { photoId in
                    sample.holdsPhotos ? UIImage.sampleMealPhoto(for: photoId) : nil
                },
                now: DeviceClock.live.now,
                capture: { _ in },
                correctMealTime: { _, _ in },
                deleteMeal: { _, _ in },
                addDish: { _, _ in },
                dishActions: .noop,
                returnToTimeline: {},
                rejectedLines: [],
                confirmsDeletion: sample.confirmsDeletion
            )
        }
    }

    extension MealScreen {
        fileprivate enum Sample: CaseIterable {
            /// この端末で撮って、まだ送れていない。料理の一覧の場所は空で、合計は「—」
            case notSent
            /// ほかの端末で、写真がまだサーバーに届いていない。写真の場所に回る印
            case awaitingPhotosOnAnotherDevice
            /// 推定している
            case estimating
            /// 2枚の写真の食事を推定できた。成分表を使ったので「栄養の出典 ›」があり、P は「以上」
            case estimated
            /// 推定できた。成分表を使っていないので「栄養の出典 ›」の行が無く、出どころは1種類で数を書かない
            case estimatedWithoutFoodComposition
            /// 推定できたが、料理と材料がまだ届いていない
            case estimatedBeforeDishesArrive
            /// 写真に料理が写っていなかった。0 kcal
            case noDishes
            /// その日の回数を使い切ったので、明日推定する
            case deferredToNextDay
            /// 推定できなかった。0 kcal。理由の下に料理を足せることを添える
            case failed
            /// 推定できなかった食事に料理を足し、推定し直している。理由の文に代えて料理の行を出す
            case failedWithAddedDish
            /// 推定できた食事で「食事を削除」を押し、画面の下から確かめている
            case confirmingDeletion

            var card: MealCard {
                switch self {
                case .notSent:
                    MealCard(meal: lunch(photoCount: 1), status: nil, recordedOnThisDevice: true)
                case .awaitingPhotosOnAnotherDevice:
                    MealCard(
                        meal: lunch(photoCount: 1), status: .awaitingPhotos,
                        recordedOnThisDevice: false)
                case .estimating:
                    MealCard(
                        meal: lunch(photoCount: 1), status: .estimating,
                        recordedOnThisDevice: true)
                case .estimated:
                    .sampleEstimated(lunch(photoCount: 2))
                case .estimatedWithoutFoodComposition:
                    .sampleBlackCoffee(lunch(photoCount: 1))
                case .estimatedBeforeDishesArrive:
                    MealCard(
                        meal: lunch(photoCount: 1), status: .estimated,
                        recordedOnThisDevice: true)
                case .noDishes:
                    MealCard(
                        meal: lunch(photoCount: 1), status: .noDishes, recordedOnThisDevice: true)
                case .deferredToNextDay:
                    MealCard(
                        meal: lunch(photoCount: 3), status: .deferredToNextDay,
                        recordedOnThisDevice: true)
                case .failed:
                    MealCard(
                        meal: lunch(photoCount: 1), status: .failed, recordedOnThisDevice: true)
                case .failedWithAddedDish:
                    addedMisoSoup(to: lunch(photoCount: 1))
                case .confirmingDeletion:
                    .sampleEstimated(lunch(photoCount: 1))
                }
            }

            var confirmsDeletion: Bool {
                switch self {
                case .confirmingDeletion: true
                case .notSent, .awaitingPhotosOnAnotherDevice, .estimating, .estimated,
                    .estimatedWithoutFoodComposition, .estimatedBeforeDishesArrive, .noDishes,
                    .deferredToNextDay, .failed, .failedWithAddedDish:
                    false
                }
            }

            /// 写真をまだ持っていない端末では、取りに行っても届かない
            var holdsPhotos: Bool {
                switch self {
                case .awaitingPhotosOnAnotherDevice: false
                case .notSent, .estimating, .estimated, .estimatedWithoutFoodComposition,
                    .estimatedBeforeDishesArrive, .noDishes, .deferredToNextDay, .failed,
                    .failedWithAddedDish, .confirmingDeletion:
                    true
                }
            }

            private func addedMisoSoup(to meal: Meal) -> MealCard {
                let dish = Dish(
                    id: UUID(), mealId: meal.id, name: "味噌汁", quantity: nil, positionInMeal: 0,
                    version: 1)
                return MealCard(
                    meal: meal, status: .failed, recordedOnThisDevice: true, dishes: [dish],
                    ingredients: [], dishEstimationStatuses: [dish.id: .estimating])
            }

            private func lunch(photoCount: Int) -> Meal {
                .sample(on: .sampleToday, at: 12, 10, photoCount: photoCount)
            }
        }
    }
#endif
