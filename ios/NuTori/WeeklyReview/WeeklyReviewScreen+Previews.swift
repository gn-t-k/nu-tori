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
                    Goal.sampleWeeklyReviewed.startedDay.startOfWeek
                case .inProgress: WeeklyReview.sampleMonday
                }
            }

            func recap(monday: CalendarDay) -> WeekRecap? {
                let goals: [Goal] = self == .unavailable ? [] : [.sampleWeeklyReviewed]
                return WeekRecap(
                    weekOf: monday, today: .sampleToday,
                    records: GoalRecords(
                        goals: goals, dailyGuides: [.sampleFirst, .sampleReviewed],
                        expenditureEstimates: [.sampleFirst, .sampleReviewed],
                        weeklyReviews: [review], weightTrend: .sampleWeeklyReviewed,
                        weightRecords: WeeklyReview.sampleWeekWeightRecords),
                    meals: WeeklyReview.sampleWeekMeals)
            }

            private var review: WeeklyReview {
                switch self {
                case .reviewedFirstWeek, .inProgress, .unavailable: .sampleReviewed
                case .deferred: .sampleDeferred
                }
            }
        }
    }
#endif
