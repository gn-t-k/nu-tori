#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: DaySummarySheet.Sample.allCases) { sample in
        // シートに載せると、出てくる途中の動きを描いてしまう
        DaySummarySheet(
            timeline: sample.timeline, day: sample.day,
            weightRecords: DaySummarySheet.Sample.weightRecords,
            weightTrend: DaySummarySheet.Sample.weightTrend,
            goalRecords: sample.goalRecords, today: .sampleToday,
            startGoalSetup: sample.startsGoalSetup ? {} : nil,
            weekRecapTitle: { day in
                WeekRecap(weekOf: day, today: .sampleToday, records: sample.goalRecords, meals: [])?
                    .title
            },
            openWeightScreen: { _ in }, openGoalScreen: {}, openWeeklyReview: { _ in },
            openNextGoal: { _ in },
            onSeeOnTimeline: { _ in })
    }

    extension DaySummarySheet {
        /// 体重は、使い始める前のヘルスケアの記録が5日ある。記録のある日が7日にそろう weighedOnce の日から、
        /// 体重の傾向の速さを出す。それより前の日（firstDay、unrecorded）には出さない
        fileprivate enum Sample: CaseIterable {
            /// 体重を1回量った日。傾向の速さを出す
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
            /// 昨日から減量の目標を立てている今日。丸は1日の目安のうち食べた分だけ進み、P・F・C は「食べた量 / 目安」、
            /// 体重の下に目標の行「あと N kg・あと N 日・まだ言い切れません」と週の振り返りの行「（途中）」
            case goalLosing
            /// 昨日から維持の目標を立てている今日。体重の下に「65.0 kg を保つ・保てています」
            case goalMaintaining
            /// 減量の目標を立てた昨日。3回食べて1日の目安を超え、丸の起点に印が付く。目標の行はその日の形で書く
            case goalExceeded
            /// 昨日立てた減量の目標を、今日達成した。目標の行「72.1 kg を達成しました」と紫の行「次の目標を選ぶ」
            case goalAchieved
            /// 目標が無く、目標を立てる知らせのカードがタイムラインにある今日。体重の下に「目標を立てる」
            case goalSetupAvailable

            var timeline: Timeline {
                switch self {
                case .weighedOnce, .weighedSeveralTimes, .unrecorded, .firstDay, .foodEstimated,
                    .foodPartlyPending, .foodAllPending, .foodUnavailable,
                    .foodUnavailableWithPending, .foodWithoutMacros, .goalSetupAvailable:
                    Self.beforeGoalTimeline
                case .goalLosing, .goalExceeded: Self.goalTimeline(Self.losingGoal)
                case .goalMaintaining: Self.goalTimeline(Self.maintainingGoal)
                case .goalAchieved: Self.goalTimeline(Self.achievedGoal)
                }
            }

            var goalRecords: GoalRecords {
                let goals: [Goal] =
                    switch self {
                    case .weighedOnce, .weighedSeveralTimes, .unrecorded, .firstDay,
                        .foodEstimated, .foodPartlyPending, .foodAllPending, .foodUnavailable,
                        .foodUnavailableWithPending, .foodWithoutMacros, .goalSetupAvailable:
                        []
                    case .goalLosing, .goalExceeded: [Self.losingGoal]
                    case .goalMaintaining: [Self.maintainingGoal]
                    case .goalAchieved: [Self.achievedGoal]
                    }
                return GoalRecords(
                    goals: goals, dailyGuides: goals.map { .sample(for: $0) },
                    expenditureEstimates: [], weeklyReviews: [], weightTrend: Self.weightTrend,
                    weightRecords: Self.weightRecords)
            }

            var startsGoalSetup: Bool {
                switch self {
                case .goalSetupAvailable: true
                case .weighedOnce, .weighedSeveralTimes, .unrecorded, .firstDay, .foodEstimated,
                    .foodPartlyPending, .foodAllPending, .foodUnavailable,
                    .foodUnavailableWithPending, .foodWithoutMacros, .goalLosing, .goalMaintaining,
                    .goalExceeded, .goalAchieved:
                    false
                }
            }

            private static let losingGoal = Goal.sampleLosing(
                startedOn: CalendarDay.sampleToday.advanced(by: -1))
            private static let maintainingGoal = Goal.sampleMaintaining(
                startedOn: CalendarDay.sampleToday.advanced(by: -1))
            private static let achievedGoal = Goal(
                id: losingGoal.id, startedDay: losingGoal.startedDay,
                startingWeightTrendKilograms: losingGoal.startingWeightTrendKilograms,
                targetWeightKilograms: 72.1, decidedAt: losingGoal.decidedAt,
                timeZone: losingGoal.timeZone, direction: losingGoal.direction,
                achievement: Goal.Achievement(
                    achievedDay: .sampleToday,
                    judgedAt: losingGoal.decidedAt.addingTimeInterval(86_400),
                    timeZone: losingGoal.timeZone),
                deadlineConfirmation: nil, closure: nil)

            /// 昨日から目標を立てている。昨日は3回、今日は1回食べた
            private static func goalTimeline(_ goal: Goal) -> Timeline {
                let yesterday = CalendarDay.sampleToday.advanced(by: -1)
                return Timeline(
                    input: Timeline.Input(
                        goalRecords: GoalRecords(
                            goals: [goal], dailyGuides: [.sample(for: goal)],
                            expenditureEstimates: [], weeklyReviews: [], weightTrend: nil,
                            weightRecords: weightRecords), rejectedLines: [],
                        meals: [
                            .sampleEstimated(.sample(on: yesterday, at: 7, 40)),
                            .sampleEstimated(.sample(on: yesterday, at: 12, 10)),
                            .sampleEstimated(.sample(on: yesterday, at: 19, 30)),
                            .sampleEstimated(.sample(on: .sampleToday, at: 7, 40)),
                        ], notices: [], undelivered: .none, conversation: .none,
                        subscriptionNotices: []),
                    firstDay: startedDay,
                    today: .sampleToday)
            }

            /// 目標を立てる前の日々
            private static let beforeGoalTimeline = Timeline(
                input: Timeline.Input(
                    goalRecords: GoalRecords(
                        goals: [], dailyGuides: [], expenditureEstimates: [], weeklyReviews: [],
                        weightTrend: nil, weightRecords: weightRecords), rejectedLines: [],
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
                    ], notices: [], undelivered: .none, conversation: .none, subscriptionNotices: []
                ),
                firstDay: startedDay,
                today: .sampleToday
            )

            static let weightRecords: [WeightRecord] =
                [
                    .sample(72.8, on: startedDay, at: 7, 2, from: .manual),
                    .sample(72.4, on: .sampleToday, at: 7, 12, from: .manual),
                    .sample(72.6, on: .sampleToday, at: 12, 40, from: .sampleScaleApp),
                    .sample(72.9, on: .sampleToday, at: 22, 5, from: .manual),
                    .sample(72.5, on: startedDay.advanced(by: 2), at: 7, 15, from: .manual),
                ]
                + [-12, -11, -10, -9, -8].map { offset in
                    WeightRecord.sample(
                        73.2 + 0.05 * Double(offset + 8), on: startedDay.advanced(by: offset),
                        at: 6, 50, from: .sampleScaleApp)
                }

            /// 最初の記録の日（使い始める 12 日前）から、最後の記録の日（今日）まで
            static let weightTrend = WeightTrend.sample(
                from: startedDay.advanced(by: -12), through: .sampleToday, startingAt: 73.4,
                perDay: -0.04)

            var day: CalendarDay {
                Self.day(of: self)
            }

            private static func day(of sample: Sample) -> CalendarDay {
                switch sample {
                case .weighedOnce: startedDay.advanced(by: 2)
                case .weighedSeveralTimes, .goalSetupAvailable: .sampleToday
                case .unrecorded: startedDay.advanced(by: 1)
                case .firstDay: startedDay
                case .foodEstimated: startedDay.advanced(by: 3)
                case .foodPartlyPending: startedDay.advanced(by: 4)
                case .foodAllPending: startedDay.advanced(by: 5)
                case .foodUnavailable: startedDay.advanced(by: 6)
                case .foodUnavailableWithPending: startedDay.advanced(by: 7)
                case .foodWithoutMacros: startedDay.advanced(by: 8)
                case .goalLosing, .goalMaintaining, .goalAchieved: .sampleToday
                case .goalExceeded: CalendarDay.sampleToday.advanced(by: -1)
                }
            }

            private static let startedDay = CalendarDay.sampleToday.advanced(by: -9)
        }
    }
#endif
