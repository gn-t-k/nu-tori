#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: DaySummarySheet.Sample.allCases) { sample in
        // シートに載せると、出てくる途中の動きを描いてしまう
        DaySummarySheet(timeline: DaySummarySheet.Sample.timeline, day: sample.day) { _ in }
    }

    extension DaySummarySheet {
        fileprivate enum Sample: CaseIterable {
            /// 体重を1回量った日
            case weighedOnce
            /// 体重を3回量った日
            case weighedSeveralTimes
            /// 記録の無い日
            case unrecorded
            /// 使い始めた日。前の日へは送れない
            case firstDay
            /// 推定できた食事の日。P は「不明」の材料が混じるので「以上」
            case foodEstimated
            /// 推定できた食事と、推定中の食事が1つある日
            case foodPartlyPending
            /// 食事がどれも推定が済んでいない日
            case foodAllPending
            /// 料理なしと推定できなかった食事だけの日
            case foodUnavailable
            /// 料理なしの食事と、翌日に推定の食事だけの日
            case foodUnavailableWithPending
            /// kcal はあるが P・F・C がすべて 0 の日。空の輪の中に kcal を書く
            case foodWithoutMacros

            static let timeline = Timeline(
                input: Timeline.Input(
                    weightRecords: [
                        .sample(72.8, on: startedDay, at: 7, 2, from: .manual),
                        .sample(72.4, on: .sampleToday, at: 7, 12, from: .manual),
                        .sample(72.6, on: .sampleToday, at: 12, 40, from: .sampleScaleApp),
                        .sample(72.9, on: .sampleToday, at: 22, 5, from: .manual),
                        .sample(72.5, on: startedDay.advanced(by: 2), at: 7, 15, from: .manual),
                    ],
                    rejectedLines: [],
                    meals: [
                        .sampleEstimated(.sample(on: Self.day(of: .foodEstimated), at: 12, 10)),
                        .sampleEstimated(
                            .sample(on: Self.day(of: .foodPartlyPending), at: 7, 40)),
                        MealCard(
                            meal: .sample(on: Self.day(of: .foodPartlyPending), at: 12, 20),
                            status: .estimating, recordedOnThisDevice: true),
                        MealCard(
                            meal: .sample(on: Self.day(of: .foodAllPending), at: 12, 20),
                            status: .estimating, recordedOnThisDevice: true),
                        MealCard(
                            meal: .sample(on: Self.day(of: .foodAllPending), at: 19, 0),
                            status: nil, recordedOnThisDevice: true),
                        MealCard(
                            meal: .sample(on: Self.day(of: .foodUnavailable), at: 12, 20),
                            status: .noDishes, recordedOnThisDevice: true),
                        MealCard(
                            meal: .sample(on: Self.day(of: .foodUnavailable), at: 19, 0),
                            status: .failed, recordedOnThisDevice: true),
                        MealCard(
                            meal: .sample(
                                on: Self.day(of: .foodUnavailableWithPending), at: 12, 20),
                            status: .noDishes, recordedOnThisDevice: true),
                        MealCard(
                            meal: .sample(on: Self.day(of: .foodUnavailableWithPending), at: 19, 0),
                            status: .deferredToNextDay, recordedOnThisDevice: true),
                        .sampleBlackCoffee(.sample(on: Self.day(of: .foodWithoutMacros), at: 9, 0)),
                    ],
                    rejectedMealLines: []),
                firstDay: startedDay,
                today: .sampleToday
            )

            var day: CalendarDay {
                Self.day(of: self)
            }

            private static func day(of sample: Sample) -> CalendarDay {
                switch sample {
                case .weighedOnce: startedDay.advanced(by: 2)
                case .weighedSeveralTimes: .sampleToday
                case .unrecorded: startedDay.advanced(by: 1)
                case .firstDay: startedDay
                case .foodEstimated: startedDay.advanced(by: 3)
                case .foodPartlyPending: startedDay.advanced(by: 4)
                case .foodAllPending: startedDay.advanced(by: 5)
                case .foodUnavailable: startedDay.advanced(by: 6)
                case .foodUnavailableWithPending: startedDay.advanced(by: 7)
                case .foodWithoutMacros: startedDay.advanced(by: 8)
                }
            }

            private static let startedDay = CalendarDay.sampleToday.advanced(by: -9)
        }
    }
#endif
