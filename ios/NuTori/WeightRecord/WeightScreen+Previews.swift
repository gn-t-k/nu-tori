#if DEBUG
    import NuToriAPI
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: WeightScreen.Sample.allCases) { sample in
        NavigationStack {
            WeightScreen(
                day: WeightScreen.Sample.day,
                records: sample.records,
                firstDay: sample.startedDay,
                today: .sampleToday,
                trendChart: WeightTrendChart(
                    weightRecords: sample.records,
                    trend: sample.trend,
                    firstDay: sample.startedDay,
                    now: .sampleNow,
                    timeZone: .sampleTokyo
                ),
                rejectedLines: sample.rejectedLines,
                capture: { _ in },
                saveWeight: { _ in }
            )
        }
    }

    extension WeightScreen {
        /// 傾向のグラフは、記録のある日が7日に届くまでの見本（oneRecord から rejected）では線を引かず点だけで、
        /// 使い始めた日が4週の中にあるので区切りを引く
        fileprivate enum Sample: CaseIterable {
            /// その日の記録は1件。傾向のグラフは、線の無い点だけ
            case oneRecord
            /// その日に、ほかのアプリの記録を含めて3件ある
            case severalRecords
            /// その日に記録が無い
            case noRecord
            /// 使い始める前の記録が、ヘルスケアにある
            case beforeFirstDay
            /// その日の記録を直した値を、サーバーが受け付けなかった
            case rejected
            /// 4週より前から使っていて、傾向の線を引く。使い始めの区切りは4週の外
            case trendLine
            /// 使い始める前のヘルスケアの記録から傾向の線を通して引き、使い始めた日に区切りを引く
            case trendLineAcrossFirstDay

            static let day = CalendarDay.sampleToday.advanced(by: -1)
            static let firstDay = CalendarDay.sampleToday.advanced(by: -6)

            var startedDay: CalendarDay {
                switch self {
                case .oneRecord, .severalRecords, .noRecord, .beforeFirstDay, .rejected:
                    Self.firstDay
                case .trendLine: CalendarDay.sampleToday.advanced(by: -40)
                case .trendLineAcrossFirstDay: CalendarDay.sampleToday.advanced(by: -10)
                }
            }

            /// 同期で届いた傾向。線を引く見本は、最初の記録の日から最後の記録の日まで
            var trend: WeightTrend? {
                switch self {
                case .oneRecord, .severalRecords, .noRecord, .beforeFirstDay, .rejected:
                    nil
                case .trendLine, .trendLineAcrossFirstDay:
                    WeightTrend.sample(
                        from: Self.dailyFirstDay, through: Self.day, startingAt: 73.4,
                        perDay: -0.03)
                }
            }

            var records: [WeightRecord] {
                switch self {
                case .trendLine, .trendLineAcrossFirstDay: Self.dailyRecords
                case .oneRecord, .rejected: Self.dayRecord + Self.otherDays
                case .severalRecords:
                    Self.dayRecord + Self.otherDays + [
                        .sample(72.6, on: Self.day, at: 12, 40, from: .sampleScaleApp),
                        .sample(72.9, on: Self.day, at: 22, 5, from: .manual),
                    ]
                case .noRecord: Self.otherDays
                case .beforeFirstDay:
                    Self.dayRecord + Self.otherDays + [
                        .sample(
                            73.4, on: Self.firstDay.advanced(by: -2), at: 6, 50,
                            from: .sampleScaleApp),
                        .sample(
                            73.6, on: Self.firstDay.advanced(by: -5), at: 7, 3,
                            from: .sampleScaleApp),
                    ]
                }
            }

            var rejectedLines: [RejectedLine] {
                switch self {
                case .oneRecord, .severalRecords, .noRecord, .beforeFirstDay, .trendLine,
                    .trendLineAcrossFirstDay:
                    []
                case .rejected:
                    [
                        .weight(
                            RejectedWeightLine(
                                record: WeightRecord(
                                    id: Self.dayRecord[0].id,
                                    kilograms: 7.2,
                                    instant: Self.dayRecord[0].instant,
                                    timeZone: Self.dayRecord[0].timeZone,
                                    inputSource: .manual,
                                    version: 2
                                ),
                                serverHasValue: true
                            ))
                    ]
                }
            }

            private static let dayRecord: [WeightRecord] = [
                .sample(72.4, on: day, at: 7, 12, from: .manual)
            ]

            /// 傾向の見本の、最初の記録の日
            private static let dailyFirstDay = CalendarDay.sampleToday.advanced(by: -45)

            /// 45 日前から、その日（昨日）まで、ときどき抜けながら毎朝量った記録。今日はまだ量っていない
            private static let dailyRecords: [WeightRecord] = {
                let wobbles = [0.2, -0.1, 0.3, 0.0, -0.2, 0.1, -0.3]
                return (0...dailyFirstDay.distance(to: day))
                    .filter { $0 % 6 != 4 }
                    .map { offset in
                        WeightRecord.sample(
                            73.4 - 0.03 * Double(offset) + wobbles[offset % wobbles.count],
                            on: dailyFirstDay.advanced(by: offset), at: 7, 5,
                            from: offset % 3 == 0 ? .sampleScaleApp : .manual)
                    }
            }()

            private static let otherDays: [WeightRecord] = [
                .sample(72.8, on: firstDay, at: 7, 2, from: .manual),
                .sample(72.6, on: firstDay.advanced(by: 2), at: 6, 48, from: .sampleScaleApp),
                .sample(72.5, on: firstDay.advanced(by: 3), at: 7, 15, from: .manual),
            ]
        }
    }
#endif
