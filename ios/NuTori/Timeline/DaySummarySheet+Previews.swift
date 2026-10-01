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

            static let timeline = Timeline(
                input: Timeline.Input(
                    weightRecords: [
                        .sample(72.8, on: startedDay, at: 7, 2, from: .manual),
                        .sample(72.4, on: .sampleToday, at: 7, 12, from: .manual),
                        .sample(72.6, on: .sampleToday, at: 12, 40, from: .sampleScaleApp),
                        .sample(72.9, on: .sampleToday, at: 22, 5, from: .manual),
                        .sample(72.5, on: startedDay.advanced(by: 2), at: 7, 15, from: .manual),
                    ],
                    rejectedLines: [], meals: [], rejectedMealLines: []),
                firstDay: startedDay,
                today: .sampleToday
            )

            var day: CalendarDay {
                switch self {
                case .weighedOnce: Self.startedDay.advanced(by: 2)
                case .weighedSeveralTimes: .sampleToday
                case .unrecorded: Self.startedDay.advanced(by: 1)
                case .firstDay: Self.startedDay
                }
            }

            private static let startedDay = CalendarDay.sampleToday.advanced(by: -3)
        }
    }
#endif
