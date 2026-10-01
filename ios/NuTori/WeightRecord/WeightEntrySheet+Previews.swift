#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: WeightEntrySheet.Sample.allCases) { sample in
        // シートに載せると、出てくる途中の動きを描いてしまう
        WeightEntrySheet(
            records: sample.records,
            today: .sampleToday,
            now: { .now },
            capture: { _ in },
            onRecord: { _ in }
        )
    }

    extension WeightEntrySheet {
        fileprivate enum Sample: CaseIterable {
            /// 体重の記録が1件も無い。キーボードで始める
            case firstTime
            /// 前の日までの記録がある。前回の値で始める
            case previousDay
            /// 今日もう手で記録した。その値で始め、記録すると直す
            case recordedToday

            var records: [WeightRecord] {
                switch self {
                case .firstTime: []
                case .previousDay: Self.yesterday
                case .recordedToday:
                    Self.yesterday + [.sample(71.8, on: .sampleToday, at: 7, 5, from: .manual)]
                }
            }

            private static let yesterday: [WeightRecord] = [
                .sample(
                    72.4, on: CalendarDay.sampleToday.advanced(by: -1), at: 7, 12, from: .manual)
            ]
        }
    }
#endif
