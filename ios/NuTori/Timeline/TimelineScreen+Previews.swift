#if DEBUG
    import NuToriAPI
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: TimelineScreen.Sample.allCases) { sample in
        TimelineScreen(
            records: sample.records,
            weightTrend: sample.weightTrend,
            initialPull: sample.initialPull,
            today: .sampleToday,
            now: DeviceClock.live.now,
            timeZone: DeviceClock.live.timeZone,
            rejectedLines: sample.rejectedLines,
            meals: sample.meals,
            notices: sample.notices,
            goals: sample.goals,
            dailyGuides: sample.dailyGuides,
            weeklyReviews: sample.weeklyReviews,
            expenditureEstimates: sample.expenditureEstimates,
            undeliveredRecords: sample.undeliveredRecords,
            capture: { _ in },
            reminderLanding: nil,
            noteReminderLanded: {},
            requestNotificationPermission: {},
            prepareWeightEntry: {},
            saveWeight: { _ in },
            sendText: { _ in },
            accountActions: .noop,
            paywallActions: .noop,
            mealActions: .noop,
            conversation: sample.conversation,
            conversationActions: .noop,
            goalSetupFlow: .notStarted,
            goalScreenGoalSetupFlow: .notStarted,
            openGoalSetupFlow: { _, _ in }
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
            /// meals と同じ記録で、今日から目標を立てた。今日の丸は1日の目安（1,850 kcal）のうち食べた分だけ進む
            case goalDecided
            /// 今日はまだ量っておらず、8:00 に体重の知らせが出た。一昨日の知らせには答えていない
            case awaitingNotice
            /// 今日の体重の知らせの中で記録した。答えた知らせは並べない
            case answeredNotice
            /// インターネットにつながらないあいだに、今日の体重と食事を記録した。どちらもまだ届いていない
            case undelivered
            /// 文章で食事を記録した。食事が1つの文章、前の日の夜を含む3つの文章、食事をすべて消した文章がある
            case writtenMeals
            /// 9月14日（月）に立てた目標の1週目を、今日（木）に見直した。振り返りのカードと変更の知らせ、左上の目標の入口
            case weeklyReviewed

            var weightTrend: WeightTrend? {
                self == .weeklyReviewed ? WeightTrend.sampleWeeklyReviewed : nil
            }

            var weeklyReviews: [WeeklyReview] {
                self == .weeklyReviewed ? [WeeklyReview.sampleReviewed] : []
            }

            var expenditureEstimates: [ExpenditureEstimate] {
                self == .weeklyReviewed
                    ? [
                        ExpenditureEstimate.sampleFirst, ExpenditureEstimate.sampleReviewed,
                    ] : []
            }

            var initialPull: TimelineScreen.InitialPull {
                switch self {
                case .loading: .inProgress
                case .firstDay: .completed(startedDay: .sampleToday)
                case .unrecordedToday, .recordedToday, .rejected, .meals, .goalDecided,
                    .awaitingNotice,
                    .answeredNotice, .undelivered, .writtenMeals:
                    .completed(startedDay: Self.startedDay)
                case .startedDayUndecided: .completed(startedDay: nil)
                case .weeklyReviewed:
                    .completed(startedDay: Goal.sampleWeeklyReviewed.startedDay)
                }
            }

            var records: [WeightRecord] {
                switch self {
                case .loading, .firstDay: []
                case .unrecordedToday, .startedDayUndecided, .awaitingNotice: Self.pastRecords
                case .recordedToday, .meals, .goalDecided, .writtenMeals:
                    Self.pastRecords + [.sample(71.8, on: .sampleToday, at: 7, 5, from: .manual)]
                case .answeredNotice:
                    Self.pastRecords + [.sample(71.8, on: .sampleToday, at: 9, 30, from: .manual)]
                case .undelivered: Self.pastRecords + [Self.undeliveredRecord]
                case .rejected: [Self.correctedRecord]
                case .weeklyReviewed: WeightRecord.sampleWeeklyReviewedWeek
                }
            }

            var rejectedLines: [RejectedLine] {
                switch self {
                case .loading, .firstDay, .unrecordedToday, .recordedToday, .startedDayUndecided,
                    .meals, .goalDecided, .awaitingNotice, .answeredNotice, .undelivered,
                    .writtenMeals, .weeklyReviewed:
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
                case .weeklyReviewed: MealCard.sampleWeeklyReviewedWeek
                case .undelivered:
                    [MealCard(meal: Self.undeliveredMeal, status: nil, recordedOnThisDevice: true)]
                case .meals, .goalDecided:
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
                case .writtenMeals:
                    [
                        .sampleEstimated(
                            .sampleWritten(
                                from: Self.oneMealText, eatenOn: .sampleToday, at: 12, 0)),
                        MealCard(
                            meal: .sampleWritten(
                                from: Self.threeMealsText,
                                eatenOn: CalendarDay.sampleToday.advanced(by: -1), at: 19, 0),
                            status: .estimating, recordedOnThisDevice: false),
                        .sampleEstimated(
                            .sampleWritten(
                                from: Self.threeMealsText, eatenOn: .sampleToday, at: 7, 30)),
                        .sampleEstimated(
                            .sampleWritten(
                                from: Self.threeMealsText, eatenOn: .sampleToday, at: 12, 30)),
                    ]
                }
            }

            var conversation: Timeline.Conversation {
                switch self {
                case .loading, .firstDay, .unrecordedToday, .recordedToday, .startedDayUndecided,
                    .rejected, .meals, .goalDecided, .awaitingNotice, .answeredNotice, .undelivered,
                    .weeklyReviewed:
                    .none
                case .writtenMeals:
                    Timeline.Conversation(
                        sentTexts: [Self.oneMealText, Self.threeMealsText, Self.deletedMealsText],
                        statuses: Dictionary(
                            uniqueKeysWithValues: [
                                Self.oneMealText, Self.threeMealsText, Self.deletedMealsText,
                            ].map {
                                ($0.id, SentTextStatus(classification: .meal, reply: .notRequested))
                            }),
                        replies: [], streams: [:])
                }
            }

            var notices: [Notice] {
                switch self {
                case .loading, .unrecordedToday, .recordedToday, .startedDayUndecided,
                    .rejected, .meals, .undelivered, .writtenMeals, .weeklyReviewed:
                    []
                case .firstDay:
                    [.sampleGoalSetup(on: .sampleToday, answered: false)]
                case .goalDecided:
                    [.sampleGoalSetup(on: .sampleToday, answered: true)]
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

            var goals: [Goal] {
                switch self {
                case .goalDecided: [Self.goal]
                case .weeklyReviewed: [Goal.sampleWeeklyReviewed]
                case .loading, .firstDay, .unrecordedToday, .recordedToday, .startedDayUndecided,
                    .rejected, .meals, .awaitingNotice, .answeredNotice, .undelivered,
                    .writtenMeals:
                    []
                }
            }

            var dailyGuides: [DailyGuide] {
                switch self {
                case .goalDecided: [.sample(for: Self.goal)]
                case .weeklyReviewed:
                    [DailyGuide.sampleFirst, DailyGuide.sampleReviewed]
                case .loading, .firstDay, .unrecordedToday, .recordedToday, .startedDayUndecided,
                    .rejected, .meals, .awaitingNotice, .answeredNotice, .undelivered,
                    .writtenMeals:
                    []
                }
            }

            private static let goal = Goal.sampleLosing(startedOn: .sampleToday)

            var undeliveredRecords: UndeliveredRecords {
                switch self {
                case .loading, .firstDay, .unrecordedToday, .recordedToday, .startedDayUndecided,
                    .rejected, .meals, .goalDecided, .awaitingNotice, .answeredNotice,
                    .writtenMeals, .weeklyReviewed:
                    .none
                case .undelivered:
                    UndeliveredRecords(records: [
                        UndeliveredRecords.Record(
                            kind: .weightRecord, id: Self.undeliveredRecord.id),
                        UndeliveredRecords.Record(kind: .meal, id: Self.undeliveredMeal.id),
                    ])
                }
            }

            private static let startedDay = CalendarDay.sampleToday.advanced(by: -10)

            private static let undeliveredRecord = WeightRecord.sample(
                71.8, on: .sampleToday, at: 7, 5, from: .manual)

            private static let undeliveredMeal = Meal.sample(on: .sampleToday, at: 12, 10)

            private static let oneMealText = SentText.sample(
                "昼はうどん", on: .sampleToday, at: 12, 0)

            private static let threeMealsText = SentText.sample(
                "昨日の夜はカレー、朝はパン、昼はうどん", on: .sampleToday, at: 15, 0)

            /// 食事をすべて消した文章。吹き出しだけが残る
            private static let deletedMealsText = SentText.sample(
                "夜はラーメン", on: .sampleToday, at: 21, 0)

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
