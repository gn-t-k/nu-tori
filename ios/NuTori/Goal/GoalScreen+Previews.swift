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
            /// 1週目を見直したところ。推定消費カロリーと1日の目安は数字で出す
            case inProgressFigures
            /// 3週を見直し、1週を見送った。グラフに見送りの印
            case inProgressDrawn
            /// 期限より前に達成した。推定消費カロリーと1日の目安は出さない
            case achieved

            var overview: GoalOverview? {
                let scene = WeeklyReviewPreviewScene.self
                switch self {
                case .inProgressFigures:
                    return overview(
                        goal: scene.goal, guides: [scene.firstGuide, scene.reviewedGuide],
                        estimates: [scene.firstEstimate, scene.reviewedEstimate],
                        reviews: [scene.review()])
                case .inProgressDrawn:
                    let later = (1...3).map { week in
                        let monday = scene.monday.advanced(by: 7 * week)
                        let estimate = ExpenditureEstimate(
                            id: UUID(), effectiveDay: monday,
                            expenditureKilocalories: 2140 - week * 20,
                            estimatedAt: scene.goal.decidedAt, initialSource: nil)
                        let guide = DailyGuide(
                            id: UUID(), goalId: scene.goal.id, expenditureEstimateId: estimate.id,
                            effectiveDay: monday, energyKilocalories: 1850 - week * 15,
                            proteinGrams: 130, fatGrams: 50, carbohydrateGrams: 215,
                            limitHits: [])
                        return (estimate, guide)
                    }
                    let deferred = WeeklyReview(
                        id: UUID(), effectiveDay: scene.monday.advanced(by: 28),
                        reviewedAt: scene.goal.decidedAt, timeZone: scene.goal.timeZone,
                        outcome: .deferred(reason: .fewMealRecords, goalId: scene.goal.id))
                    return overview(
                        goal: scene.goal,
                        guides: [scene.firstGuide, scene.reviewedGuide] + later.map(\.1),
                        estimates: [scene.firstEstimate, scene.reviewedEstimate] + later.map(\.0),
                        reviews: [scene.review(), deferred],
                        today: scene.monday.advanced(by: 30))
                case .achieved:
                    let goal = scene.goal
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
                        goal: achieved, guides: [scene.firstGuide, scene.reviewedGuide],
                        estimates: [scene.firstEstimate, scene.reviewedEstimate],
                        reviews: [scene.review()])
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
                        weightTrend: WeeklyReviewPreviewScene.weightTrend,
                        weightRecords: WeeklyReviewPreviewScene.weightRecords))
            }
        }
    }
#endif
