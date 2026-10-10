#if DEBUG
    import NuToriCore
    import SwiftUI
    import UIKit

    #Preview("状態ごと", arguments: MealCardView.Sample.allCases) { sample in
        MealCardView(card: sample.card) { photoId in
            sample.holdsPhotos ? UIImage.sampleMealPhoto(for: photoId) : nil
        }
        .modifier(OwnRecordCard())
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    extension MealCardView {
        fileprivate enum Sample: CaseIterable {
            /// この端末で撮って、まだ送れていない。写真と時刻だけ
            case notSent
            /// ほかの端末で、写真がまだサーバーに届いていない。写真の場所に回る印
            case awaitingPhotosOnAnotherDevice
            /// 2枚の写真を選び、サーバーが推定している
            case estimating
            /// 推定できた。料理の名前を「・」でつなぎ、kcal と P・F・C を出す（P は「以上」）
            case estimated
            /// 推定できたが、料理と材料がまだ届いていない。名前の場所は空
            case estimatedBeforeDishesArrive
            /// 3枚の写真に、料理が写っていなかった
            case noDishes
            /// 4枚の写真の食事を、その日の回数を使い切ったので明日推定する
            case deferredToNextDay
            /// 推定できなかった
            case failed
            /// 前の日に撮っておいた写真を、今日選んだ。撮った日を添える
            case pickedFromEarlierDay
            /// 2台目の端末で、縮小版をまだ取りに行っている
            case fetchingOnAnotherDevice

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
                        meal: lunch(photoCount: 2), status: .estimating,
                        recordedOnThisDevice: true)
                case .estimated:
                    .sampleEstimated(lunch(photoCount: 1))
                case .estimatedBeforeDishesArrive:
                    MealCard(
                        meal: lunch(photoCount: 1), status: .estimated,
                        recordedOnThisDevice: true)
                case .noDishes:
                    MealCard(
                        meal: lunch(photoCount: 3), status: .noDishes, recordedOnThisDevice: true)
                case .deferredToNextDay:
                    MealCard(
                        meal: lunch(photoCount: 4), status: .deferredToNextDay,
                        recordedOnThisDevice: true)
                case .failed:
                    MealCard(
                        meal: lunch(photoCount: 1), status: .failed, recordedOnThisDevice: true)
                case .pickedFromEarlierDay:
                    MealCard(
                        meal: .samplePicked(
                            eatenOn: CalendarDay.sampleToday.advanced(by: -1), at: 19, 40,
                            sentOn: .sampleToday, photoCount: 2),
                        status: .estimating,
                        recordedOnThisDevice: true)
                case .fetchingOnAnotherDevice:
                    MealCard(
                        meal: lunch(photoCount: 2), status: .estimating,
                        recordedOnThisDevice: false)
                }
            }

            /// 写真をまだ持っていない端末では、取りに行っても届かない
            var holdsPhotos: Bool {
                switch self {
                case .awaitingPhotosOnAnotherDevice, .fetchingOnAnotherDevice: false
                case .notSent, .estimating, .estimated, .estimatedBeforeDishesArrive, .noDishes,
                    .deferredToNextDay, .failed, .pickedFromEarlierDay:
                    true
                }
            }

            private func lunch(photoCount: Int) -> Meal {
                .sample(on: .sampleToday, at: 12, 10, photoCount: photoCount)
            }
        }
    }
#endif
