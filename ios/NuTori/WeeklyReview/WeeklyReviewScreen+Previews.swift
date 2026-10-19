#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: WeeklyReviewScreen.Sample.allCases) { sample in
        NavigationStack {
            WeeklyReviewScreen(
                monday: sample.monday, entry: .weeklyReviewCard, recap: sample.recap(monday:),
                capture: { _ in }, returnToTimeline: { _ in })
        }
    }

    extension WeeklyReviewScreen {
        fileprivate enum Sample: CaseIterable {
            /// 1週目を見直した週。一番下に次の週の1日の目安と、変わった理由
            case reviewedFirstWeek
            /// 食事の記録が少なくて見送った週。一番下は「そのまま」と見送った理由
            case deferred
            /// 今週（途中）。一番上は今日で判定し、次の週の1日の目安は出さない
            case inProgress
            /// 組めない週（目標の記録が消えた）。タイムラインに戻る
            case unavailable

            var monday: CalendarDay {
                switch self {
                case .reviewedFirstWeek, .deferred, .unavailable:
                    WeeklyReviewPreviewScene.goal.startedDay.startOfWeek
                case .inProgress: WeeklyReviewPreviewScene.monday
                }
            }

            func recap(monday: CalendarDay) -> WeekRecap? {
                let scene = WeeklyReviewPreviewScene.self
                let goals = self == .unavailable ? [] : [scene.goal]
                return WeekRecap(
                    weekOf: monday, today: .sampleToday,
                    records: GoalRecords(
                        goals: goals, dailyGuides: [scene.firstGuide, scene.reviewedGuide],
                        expenditureEstimates: [scene.firstEstimate, scene.reviewedEstimate],
                        weeklyReviews: [scene.review(deferred: self == .deferred)],
                        weightTrend: scene.weightTrend, weightRecords: scene.weightRecords),
                    meals: scene.meals)
            }
        }
    }
#endif
