#if DEBUG
    import NuToriAPI
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: WeightScreen.Sample.allCases) { sample in
        NavigationStack {
            WeightScreen(
                day: WeightScreen.Sample.day,
                records: sample.records,
                firstDay: WeightScreen.Sample.firstDay,
                today: .sampleToday,
                rejectedLines: sample.rejectedLines,
                capture: { _ in },
                saveWeight: { _ in }
            )
        }
    }

    extension WeightScreen {
        fileprivate enum Sample: CaseIterable {
            /// その日の記録は1件
            case oneRecord
            /// その日に、ほかのアプリの記録を含めて3件ある
            case severalRecords
            /// その日に記録が無い
            case noRecord
            /// 使い始める前の記録が、ヘルスケアにある
            case beforeFirstDay
            /// その日の記録を直した値を、サーバーが受け付けなかった
            case rejected

            static let day = CalendarDay.sampleToday.advanced(by: -1)
            static let firstDay = CalendarDay.sampleToday.advanced(by: -6)

            var records: [WeightRecord] {
                switch self {
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

            var rejectedLines: [RejectedWeightLine] {
                switch self {
                case .oneRecord, .severalRecords, .noRecord, .beforeFirstDay: []
                case .rejected:
                    [
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
                        )
                    ]
                }
            }

            private static let dayRecord: [WeightRecord] = [
                .sample(72.4, on: day, at: 7, 12, from: .manual)
            ]

            private static let otherDays: [WeightRecord] = [
                .sample(72.8, on: firstDay, at: 7, 2, from: .manual),
                .sample(72.6, on: firstDay.advanced(by: 2), at: 6, 48, from: .sampleScaleApp),
                .sample(72.5, on: firstDay.advanced(by: 3), at: 7, 15, from: .manual),
            ]
        }
    }
#endif
