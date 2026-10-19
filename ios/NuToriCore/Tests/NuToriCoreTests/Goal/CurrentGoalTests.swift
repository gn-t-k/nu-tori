import Foundation
import NuToriCore
import Testing

@Suite("今の目標")
struct CurrentGoalTests {
    static func guide(of goal: Goal, from day: CalendarDay) -> DailyGuide {
        DailyGuide(
            id: UUID(), goalId: goal.id, expenditureEstimateId: UUID(), effectiveDay: day,
            energyKilocalories: 1850, proteinGrams: 130, fatGrams: 50, carbohydrateGrams: 220,
            limitHits: [])
    }

    @Suite("目標が無いとき")
    struct NoGoal {
        @Test("今の目標が無いこと")
        func isNil() {
            #expect(
                CurrentGoal(
                    today: CalendarDay(year: 2026, month: 10, day: 10), goals: [], dailyGuides: [])
                    == nil)
        }
    }

    @Suite("今日を含む目標に、今日より前から当てる1日の目安が2つあるとき")
    struct GoalContainingToday {
        let goal: Goal
        let olderGuide: DailyGuide
        let newerGuide: DailyGuide
        let current: CurrentGoal?

        init() throws {
            let closed = try Goal.losing(
                closure: Goal.Closure(
                    endedDay: CalendarDay(year: 2026, month: 10, day: 1), nextGoalId: UUID(),
                    endReason: .switched))
            goal = try Goal.losing(
                startedOn: CalendarDay(year: 2026, month: 10, day: 1))
            olderGuide = CurrentGoalTests.guide(
                of: goal, from: CalendarDay(year: 2026, month: 10, day: 1))
            newerGuide = CurrentGoalTests.guide(
                of: goal, from: CalendarDay(year: 2026, month: 10, day: 8))
            current = CurrentGoal(
                today: CalendarDay(year: 2026, month: 10, day: 10), goals: [closed, goal],
                dailyGuides: [newerGuide, olderGuide])
        }

        @Test("今日を含む目標を今の目標にすること")
        func choosesGoalContainingToday() {
            #expect(current?.goal == goal)
        }

        @Test("当てる始まりの日が今日以前で最も遅い1日の目安を出すこと")
        func choosesLatestGuideSinceToday() {
            #expect(current?.dailyGuide == newerGuide)
        }
    }

    @Suite("今日を含む目標が無く、今日より後に始まる閉じていない目標があるとき（西へ移った）")
    struct GoalStartingAfterToday {
        let goal: Goal
        let earlierGuide: DailyGuide
        let current: CurrentGoal?

        init() throws {
            goal = try Goal.losing(
                startedOn: CalendarDay(year: 2026, month: 10, day: 11))
            earlierGuide = CurrentGoalTests.guide(
                of: goal, from: CalendarDay(year: 2026, month: 10, day: 11))
            current = CurrentGoal(
                today: CalendarDay(year: 2026, month: 10, day: 10), goals: [goal],
                dailyGuides: [
                    CurrentGoalTests.guide(
                        of: goal, from: CalendarDay(year: 2026, month: 10, day: 18)),
                    earlierGuide,
                ])
        }

        @Test("閉じていない目標を今の目標にすること")
        func choosesOpenGoal() {
            #expect(current?.goal == goal)
        }

        @Test("当てる始まりの日が最も早い1日の目安を出すこと")
        func choosesEarliestGuide() {
            #expect(current?.dailyGuide == earlierGuide)
        }
    }

    @Suite("今の目標の1日の目安がまだ届いていないとき")
    struct GuideNotArrived {
        let current: CurrentGoal?

        init() throws {
            current = CurrentGoal(
                today: CalendarDay(year: 2026, month: 10, day: 10), goals: [try .losing()],
                dailyGuides: [])
        }

        @Test("1日の目安を出さないこと")
        func hasNoGuide() {
            #expect(current?.dailyGuide == nil)
        }
    }
}
