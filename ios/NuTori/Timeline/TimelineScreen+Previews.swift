#if DEBUG
    import NuToriAPI
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: TimelineScreen.Sample.allCases) { sample in
        TimelineScreen(
            records: sample.records,
            weightTrend: nil,
            initialPull: sample.initialPull,
            today: .sampleToday,
            now: DeviceClock.live.now,
            timeZone: DeviceClock.live.timeZone,
            rejectedLines: sample.rejectedLines,
            meals: sample.meals,
            notices: sample.notices,
            undeliveredRecords: sample.undeliveredRecords,
            capture: { _ in },
            reminderLanding: nil,
            noteReminderLanded: {},
            requestNotificationPermission: {},
            prepareWeightEntry: {},
            saveWeight: { _ in },
            sendText: { _ in },
            accountActions: .noop,
            mealActions: .noop,
            conversation: .none,
            conversationActions: .none
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
            /// 作った記録と直した記録と食事を、サーバーが受け付けなかった
            case rejected
            /// 朝の食事は推定できて今日の丸が塗られ、昼の食事は推定の途中で、撮っておいた昨日の写真を選んだばかり
            case meals
            /// 今日はまだ量っておらず、8:00 に体重の知らせが出た。一昨日の知らせには答えていない
            case awaitingNotice
            /// 今日の体重の知らせの中で記録した。答えた知らせは並べない
            case answeredNotice
            /// インターネットにつながらないあいだに、今日の体重と食事を記録した。どちらもまだ届いていない
            case undelivered

            var initialPull: TimelineScreen.InitialPull {
                switch self {
                case .loading: .inProgress
                case .firstDay: .completed(startedDay: .sampleToday)
                case .unrecordedToday, .recordedToday, .rejected, .meals, .awaitingNotice,
                    .answeredNotice, .undelivered:
                    .completed(startedDay: Self.startedDay)
                case .startedDayUndecided: .completed(startedDay: nil)
                }
            }

            var records: [WeightRecord] {
                switch self {
                case .loading, .firstDay: []
                case .unrecordedToday, .startedDayUndecided, .awaitingNotice: Self.pastRecords
                case .recordedToday, .meals:
                    Self.pastRecords + [.sample(71.8, on: .sampleToday, at: 7, 5, from: .manual)]
                case .answeredNotice:
                    Self.pastRecords + [.sample(71.8, on: .sampleToday, at: 9, 30, from: .manual)]
                case .undelivered: Self.pastRecords + [Self.undeliveredRecord]
                case .rejected: [Self.correctedRecord]
                }
            }

            var rejectedLines: [RejectedLine] {
                switch self {
                case .loading, .firstDay, .unrecordedToday, .recordedToday, .startedDayUndecided,
                    .meals, .awaitingNotice, .answeredNotice, .undelivered:
                    []
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
                        .meal(RejectedMealLine(meal: .sample(on: .sampleToday, at: 12, 10))),
                    ]
                }
            }

            var meals: [MealCard] {
                switch self {
                case .loading, .firstDay, .unrecordedToday, .recordedToday, .startedDayUndecided,
                    .rejected, .awaitingNotice, .answeredNotice:
                    []
                case .undelivered:
                    [MealCard(meal: Self.undeliveredMeal, status: nil, recordedOnThisDevice: true)]
                case .meals:
                    [
                        // 推定できた食事で、帯の今日の丸が P・F・C の割合で塗られる
                        .sampleEstimated(.sample(on: .sampleToday, at: 7, 40)),
                        MealCard(
                            meal: .sample(on: .sampleToday, at: 12, 10, photoCount: 2),
                            status: .estimating, recordedOnThisDevice: true),
                        MealCard(
                            meal: .samplePicked(
                                eatenOn: CalendarDay.sampleToday.advanced(by: -1), at: 19, 40,
                                sentOn: .sampleToday, photoCount: 3),
                            status: nil, recordedOnThisDevice: true),
                    ]
                }
            }

            var notices: [Notice] {
                switch self {
                case .loading, .firstDay, .unrecordedToday, .recordedToday, .startedDayUndecided,
                    .rejected, .meals, .undelivered:
                    []
                case .awaitingNotice:
                    [
                        .sampleMissedWeightRecord(
                            on: CalendarDay.sampleToday.advanced(by: -2), respondedAt: nil),
                        .sampleMissedWeightRecord(on: .sampleToday, respondedAt: nil),
                    ]
                case .answeredNotice:
                    [
                        .sampleMissedWeightRecord(
                            on: .sampleToday, respondedAt: (hour: 9, minute: 30))
                    ]
                }
            }

            var undeliveredRecords: UndeliveredRecords {
                switch self {
                case .loading, .firstDay, .unrecordedToday, .recordedToday, .startedDayUndecided,
                    .rejected, .meals, .awaitingNotice, .answeredNotice:
                    .none
                case .undelivered:
                    UndeliveredRecords(
                        pendingEntries: [
                            try? PendingWeightRecordWrite(
                                enqueuedAt: Self.undeliveredRecord.instant,
                                write: .createWeightRecord(Self.undeliveredRecord)
                            ).entry(),
                            try? PendingMealWrite(
                                enqueuedAt: Self.undeliveredMeal.sentAt,
                                write: .create(Self.undeliveredMeal)
                            ).entry(),
                        ].compactMap(\.self))
                }
            }

            private static let startedDay = CalendarDay.sampleToday.advanced(by: -10)

            private static let undeliveredRecord = WeightRecord.sample(
                71.8, on: .sampleToday, at: 7, 5, from: .manual)

            private static let undeliveredMeal = Meal.sample(on: .sampleToday, at: 12, 10)

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
                -> RejectedLine
            {
                .weight(RejectedWeightLine(record: record, serverHasValue: serverHasValue))
            }
        }
    }
#endif
