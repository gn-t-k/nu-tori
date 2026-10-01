#if DEBUG
    import NuToriAPI
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: TimelineScreen.Sample.allCases) { sample in
        TimelineScreen(
            records: sample.records,
            initialPull: sample.initialPull,
            today: .sampleToday,
            now: { .now },
            rejectedLines: sample.rejectedLines,
            capture: { _ in },
            prepareWeightEntry: {},
            saveWeight: { _ in },
            accountActions: .noop
        )
    }

    extension TimelineScreen {
        fileprivate enum Sample: CaseIterable {
            /// 初回の取得の途中
            case loading
            /// 使い始めた日で、まだ何も記録していない
            case firstDay
            /// 先週から使っていて、今日はまだ量っていない。ほかのアプリの記録と、同じ日の2件目がある
            case unrecordedToday
            /// 今日も量った
            case recordedToday
            /// 取り終えたが、使い始めた日がサーバーでまだ決まっていない
            case startedDayUndecided
            /// 作った記録と直した記録を、サーバーが受け付けなかった
            case rejected

            var initialPull: TimelineScreen.InitialPull {
                switch self {
                case .loading: .inProgress
                case .firstDay: .completed(startedDay: .sampleToday)
                case .unrecordedToday, .recordedToday, .rejected:
                    .completed(startedDay: Self.startedDay)
                case .startedDayUndecided: .completed(startedDay: nil)
                }
            }

            var records: [WeightRecord] {
                switch self {
                case .loading, .firstDay: []
                case .unrecordedToday, .startedDayUndecided: Self.pastRecords
                case .recordedToday:
                    Self.pastRecords + [.sample(71.8, on: .sampleToday, at: 7, 5, from: .manual)]
                case .rejected: [Self.correctedRecord]
                }
            }

            var rejectedLines: [RejectedWeightLine] {
                switch self {
                case .loading, .firstDay, .unrecordedToday, .recordedToday, .startedDayUndecided: []
                case .rejected:
                    [
                        Self.rejectedLine(
                            .sample(
                                71.9, on: CalendarDay.sampleToday.advanced(by: -1), at: 7, 20,
                                from: .manual),
                            serverHasValue: false),
                        Self.rejectedLine(
                            WeightRecord(
                                id: Self.correctedRecord.id,
                                kilograms: 70.2,
                                instant: Self.correctedRecord.instant,
                                timeZone: Self.correctedRecord.timeZone,
                                inputSource: .manual,
                                version: 2
                            ),
                            serverHasValue: true),
                    ]
                }
            }

            private static let startedDay = CalendarDay.sampleToday.advanced(by: -10)

            private static let pastRecords: [WeightRecord] = [
                .sample(72.8, on: startedDay, at: 7, 2, from: .manual),
                .sample(72.6, on: startedDay.advanced(by: 1), at: 6, 48, from: .sampleScaleApp),
                .sample(72.5, on: startedDay.advanced(by: 3), at: 7, 15, from: .manual),
                .sample(72.3, on: startedDay.advanced(by: 7), at: 7, 10, from: .manual),
                .sample(72.1, on: startedDay.advanced(by: 9), at: 6, 55, from: .sampleScaleApp),
                .sample(72.4, on: startedDay.advanced(by: 9), at: 21, 30, from: .manual),
            ]

            private static let correctedRecord = WeightRecord.sample(
                72.2, on: CalendarDay.sampleToday.advanced(by: -2), at: 7, 0, from: .manual)

            private static func rejectedLine(_ record: WeightRecord, serverHasValue: Bool)
                -> RejectedWeightLine
            {
                RejectedWeightLine(record: record, serverHasValue: serverHasValue)
            }
        }
    }
#endif
