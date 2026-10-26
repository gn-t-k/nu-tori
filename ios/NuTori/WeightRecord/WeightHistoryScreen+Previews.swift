#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: WeightHistoryScreen.Sample.allCases) { sample in
        NavigationStack {
            WeightHistoryScreen(
                rows: DailyWeightRecords(
                    weightRecords: sample.records, firstDay: WeightHistoryScreen.Sample.firstDay
                ).all)
        }
    }

    extension WeightHistoryScreen {
        fileprivate enum Sample: CaseIterable {
            /// 使い始めて3週。どの日も1件
            case oneRecordADay
            /// 体重計のアプリと手の記録が同じ日にあり、「ほか1件」を添える日がある
            case severalRecordsOnADay

            static let firstDay = CalendarDay.sampleToday.advanced(by: -20)

            var records: [WeightRecord] {
                let daily = (0...20).map { offset in
                    WeightRecord.sample(
                        73.0 - 0.04 * Double(offset), on: Self.firstDay.advanced(by: offset),
                        at: 7, 5, from: .manual)
                }
                switch self {
                case .oneRecordADay:
                    return daily
                case .severalRecordsOnADay:
                    return daily + [
                        .sample(
                            72.5, on: .sampleToday.advanced(by: -2), at: 21, 30,
                            from: .sampleScaleApp)
                    ]
                }
            }
        }
    }
#endif
