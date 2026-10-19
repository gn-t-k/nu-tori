import Foundation
import NuToriCore
import Testing

/// 10月1日（木）に立てた、12月24日（木）までに 72.4 kg から 68.0 kg へ減らす目標（`Goal.losing()`）などの目標の画面
@Suite("目標の画面")
struct GoalOverviewTests {
    static func day(_ month: Int, _ day: Int) -> CalendarDay {
        CalendarDay(year: 2026, month: month, day: day)
    }

    static func overview(
        today: CalendarDay, goals: [Goal], dailyGuides: [DailyGuide] = [],
        expenditureEstimates: [ExpenditureEstimate] = [], weeklyReviews: [WeeklyReview] = [],
        weightTrend: WeightTrend? = nil, weightRecords: [WeightRecord] = []
    ) -> GoalOverview? {
        GoalOverview(
            today: today,
            records: GoalRecords(
                goals: goals, dailyGuides: dailyGuides,
                expenditureEstimates: expenditureEstimates, weeklyReviews: weeklyReviews,
                weightTrend: weightTrend, weightRecords: weightRecords))
    }

    static func trend(_ days: [(CalendarDay, Double)]) -> WeightTrend {
        WeightTrend(days: days.map { WeightTrend.Day(day: $0.0, kilograms: $0.1) })
    }

    /// `Goal.losing()` に、達成・期限の日の確定・閉じたことを付けたもの
    static func losing(
        achievedOn achievedDay: CalendarDay? = nil, confirmedTrend: Double? = nil,
        closure: Goal.Closure? = nil
    ) throws -> Goal {
        let losing = try Goal.losing()
        return Goal(
            id: losing.id, startedDay: losing.startedDay,
            startingWeightTrendKilograms: losing.startingWeightTrendKilograms,
            targetWeightKilograms: losing.targetWeightKilograms, decidedAt: losing.decidedAt,
            timeZone: losing.timeZone, direction: losing.direction,
            achievement: try achievedDay.map {
                Goal.Achievement(
                    achievedDay: $0,
                    judgedAt: try Date(
                        "\($0.yearMonthDay)T07:10:00+09:00", strategy: .iso8601),
                    timeZone: losing.timeZone)
            },
            deadlineConfirmation: try confirmedTrend.map {
                Goal.DeadlineConfirmation(
                    deadlineWeightTrendKilograms: $0,
                    confirmedAt: try Date("2026-12-25T07:10:00+09:00", strategy: .iso8601),
                    timeZone: losing.timeZone)
            },
            closure: closure)
    }

    @Suite("目標がないとき")
    struct NoGoal {
        @Test("目標の画面を開かないこと")
        func hasNoOverview() {
            #expect(
                GoalOverviewTests.overview(today: GoalOverviewTests.day(11, 10), goals: []) == nil)
        }
    }
}
