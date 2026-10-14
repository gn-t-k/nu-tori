import Foundation
import NuToriCore
import Testing

@Suite("進行中の要約")
struct GoalProgressTests {
    static let today = CalendarDay(year: 2026, month: 11, day: 10)

    static func trend(_ kilograms: Double, on day: CalendarDay) -> WeightTrend {
        WeightTrend(days: [
            WeightTrend.Day(day: day.advanced(by: -1), kilograms: kilograms + 0.5),
            WeightTrend.Day(day: day, kilograms: kilograms),
        ])
    }

    @Suite("減量の目標")
    struct Losing {
        @Test("今日の体重の傾向と目標体重の差を 0.1 kg 単位で、今日から期限の日までの日数を両端を含めて出すこと")
        func showsRemainingKilogramsAndDays() throws {
            // 12月24日までに 68.0 kg
            let progress = GoalProgress(
                goal: try .losing(), today: GoalProgressTests.today,
                weightTrend: GoalProgressTests.trend(70.34, on: GoalProgressTests.today))

            #expect(progress?.text == "あと 2.3 kg・あと 45 日")
        }

        @Test("今日に体重の傾向が無ければ、今日以前で最も新しい傾向と比べること")
        func usesLatestTrendBeforeToday() throws {
            let progress = GoalProgress(
                goal: try .losing(), today: GoalProgressTests.today,
                weightTrend: GoalProgressTests.trend(
                    69.96, on: GoalProgressTests.today.advanced(by: -3)))

            #expect(progress?.text == "あと 2.0 kg・あと 45 日")
        }

        @Test("期限の日は、あと 1 日にすること")
        func countsDeadlineDayItself() throws {
            let deadline = CalendarDay(year: 2026, month: 12, day: 24)
            let progress = GoalProgress(
                goal: try .losing(), today: deadline,
                weightTrend: GoalProgressTests.trend(68.5, on: deadline))

            #expect(progress?.text == "あと 0.5 kg・あと 1 日")
        }

        @Test("体重の傾向が目標体重を越えたら、あと 0.0 kg にすること")
        func stopsAtZeroPastTarget() throws {
            let progress = GoalProgress(
                goal: try .losing(), today: GoalProgressTests.today,
                weightTrend: GoalProgressTests.trend(67.6, on: GoalProgressTests.today))

            #expect(progress?.text == "あと 0.0 kg・あと 45 日")
        }

        @Test("体重の傾向が無ければ、要約を出さないこと")
        func needsTrend() throws {
            #expect(
                GoalProgress(goal: try .losing(), today: GoalProgressTests.today, weightTrend: nil)
                    == nil)
        }
    }

    @Suite("増量の目標")
    struct Gaining {
        @Test("目標体重から今日の体重の傾向を引いた差を出すこと")
        func showsRemainingKilograms() throws {
            let losing = try Goal.losing()
            let goal = Goal(
                id: losing.id, startedDay: losing.startedDay, startingWeightTrendKilograms: 55.0,
                targetWeightKilograms: 58.0, decidedAt: losing.decidedAt,
                timeZone: losing.timeZone,
                direction: .gain(
                    Goal.WeightChange(
                        deadlineDay: CalendarDay(year: 2026, month: 11, day: 30),
                        pacePlan: .gentle)),
                closure: nil)

            let progress = GoalProgress(
                goal: goal, today: GoalProgressTests.today,
                weightTrend: GoalProgressTests.trend(56.27, on: GoalProgressTests.today))

            #expect(progress?.text == "あと 1.7 kg・あと 21 日")
        }
    }

    @Suite("維持の目標")
    struct Maintaining {
        @Test("保つ体重を出すこと")
        func showsTargetWeight() throws {
            let progress = GoalProgress(
                goal: try .maintaining(), today: GoalProgressTests.today, weightTrend: nil)

            #expect(progress?.text == "65.0 kg を保つ")
        }
    }

    @Suite("目標の列から引くとき、今日を含む目標が無いとき（今日が開始の日より前）")
    struct NoGoalContainingToday {
        let goals: [Goal]

        init() throws {
            let losing = try Goal.losing()
            goals = [
                Goal(
                    id: losing.id, startedDay: GoalProgressTests.today.advanced(by: 1),
                    startingWeightTrendKilograms: losing.startingWeightTrendKilograms,
                    targetWeightKilograms: losing.targetWeightKilograms,
                    decidedAt: losing.decidedAt, timeZone: losing.timeZone,
                    direction: losing.direction, closure: nil)
            ]
        }

        @Test("要約を出さないこと")
        func showsNothing() {
            #expect(
                GoalProgress(
                    today: GoalProgressTests.today, goals: goals, dailyGuides: [], weightTrend: nil)
                    == nil)
        }
    }

    @Suite("目標の列から引くとき、今日を含む目標があるとき")
    struct GoalContainingToday {
        let goals: [Goal]

        init() throws {
            goals = [try .losing()]
        }

        @Test("その目標の要約を出すこと")
        func showsThatGoal() {
            #expect(
                GoalProgress(
                    today: GoalProgressTests.today, goals: goals, dailyGuides: [],
                    weightTrend: GoalProgressTests.trend(70.34, on: GoalProgressTests.today))?.text
                    == "あと 2.3 kg・あと 45 日")
        }
    }
}
