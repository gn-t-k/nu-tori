#if DEBUG
    import Foundation
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: GoalScreen.Sample.allCases) { sample in
        NavigationStack {
            GoalScreen(
                overview: sample.overview, entry: .goalLink, goalSetupFlow: .notStarted,
                timeZone: DeviceClock.live.timeZone, recapTitle: { _ in "9月14日〜20日" },
                capture: { _ in }, openGoalSetup: { _ in }, openWeeklyReview: { _ in })
        }
    }

    extension GoalScreen {
        fileprivate enum Sample: CaseIterable {
            /// 1週目を見直したところ。今の1日の目安のカードに棒だけを出す
            case inProgressBars
            /// 3週を見直し、1週を見送った。棒の下にグラフを描き、見送りの印を付ける
            case inProgressDrawn
            /// 期限より前に達成した。棒とグラフは出さない
            case achieved

            var overview: GoalOverview? {
                let goal = Goal.sampleWeeklyReviewed
                let monday = WeeklyReview.sampleMonday
                switch self {
                case .inProgressBars:
                    return overview(
                        goal: goal, guides: [DailyGuide.sampleFirst, .sampleReviewed],
                        estimates: [ExpenditureEstimate.sampleFirst, .sampleReviewed],
                        reviews: [WeeklyReview.sampleReviewed])
                case .inProgressDrawn:
                    let later = (1...3).map { week in
                        let weekMonday = monday.advanced(by: 7 * week)
                        let estimate = ExpenditureEstimate(
                            id: UUID(), effectiveDay: weekMonday,
                            expenditureKilocalories: 2140 - week * 20,
                            estimatedAt: goal.decidedAt, initialSource: nil)
                        let guide = DailyGuide(
                            id: UUID(), goalId: goal.id, expenditureEstimateId: estimate.id,
                            effectiveDay: weekMonday, energyKilocalories: 1850 - week * 15,
                            proteinGrams: 130, fatGrams: 50, carbohydrateGrams: 215,
                            limitHits: [])
                        return (estimate, guide)
                    }
                    let deferred = WeeklyReview(
                        id: UUID(), effectiveDay: monday.advanced(by: 28),
                        reviewedAt: goal.decidedAt, timeZone: goal.timeZone,
                        outcome: .deferred(reason: .fewMealRecords, goalId: goal.id))
                    return overview(
                        goal: goal,
                        guides: [DailyGuide.sampleFirst, .sampleReviewed] + later.map(\.1),
                        estimates: [ExpenditureEstimate.sampleFirst, .sampleReviewed]
                            + later.map(\.0),
                        reviews: [WeeklyReview.sampleReviewed, deferred],
                        today: monday.advanced(by: 30))
                case .achieved:
                    let achieved = Goal(
                        id: goal.id, startedDay: goal.startedDay,
                        startingWeightTrendKilograms: goal.startingWeightTrendKilograms,
                        targetWeightKilograms: goal.targetWeightKilograms,
                        decidedAt: goal.decidedAt, timeZone: goal.timeZone,
                        direction: goal.direction,
                        achievement: Goal.Achievement(
                            achievedDay: .sampleToday, judgedAt: goal.decidedAt,
                            timeZone: goal.timeZone),
                        deadlineConfirmation: nil, closure: nil)
                    return overview(
                        goal: achieved, guides: [DailyGuide.sampleFirst, .sampleReviewed],
                        estimates: [ExpenditureEstimate.sampleFirst, .sampleReviewed],
                        reviews: [WeeklyReview.sampleReviewed])
                }
            }

            private func overview(
                goal: Goal, guides: [DailyGuide], estimates: [ExpenditureEstimate],
                reviews: [WeeklyReview], today: CalendarDay = .sampleToday
            ) -> GoalOverview? {
                GoalOverview(
                    today: today,
                    records: GoalRecords(
                        goals: [goal], dailyGuides: guides, expenditureEstimates: estimates,
                        weeklyReviews: reviews,
                        weightTrend: .sampleWeeklyReviewed,
                        weightRecords: WeightRecord.sampleWeeklyReviewedWeek))
            }
        }
    }
#endif
