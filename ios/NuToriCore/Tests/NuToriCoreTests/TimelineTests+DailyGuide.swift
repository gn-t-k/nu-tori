import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("1日の目安と比べる日")
    struct DailyGuideOfDay {
        /// 2026-10-06 に始めた目標と、その日から当てる1日の目安を持つ、10月5日から7日のタイムライン
        let timeline: Timeline
        let guide: DailyGuide

        init() throws {
            let goal = try Goal.losing(id: UUID())
            let startedGoal = Goal(
                id: goal.id, startedDay: CalendarDay(year: 2026, month: 10, day: 6),
                startingWeightTrendKilograms: goal.startingWeightTrendKilograms,
                targetWeightKilograms: goal.targetWeightKilograms, decidedAt: goal.decidedAt,
                timeZone: goal.timeZone, direction: goal.direction,
                achievement: nil, deadlineConfirmation: nil, closure: nil)
            guide = DailyGuide(
                id: UUID(), goalId: goal.id, expenditureEstimateId: UUID(),
                effectiveDay: CalendarDay(year: 2026, month: 10, day: 6), energyKilocalories: 1850,
                proteinGrams: 130, fatGrams: 50, carbohydrateGrams: 220, limitHits: [])
            timeline = Timeline(
                input: Timeline.Input(
                    goalRecords: GoalRecords(
                        goals: [startedGoal], dailyGuides: [guide], expenditureEstimates: [],
                        weeklyReviews: [], weightTrend: nil, weightRecords: []), rejectedLines: [],
                    meals: [], notices: [], undelivered: .none, conversation: .none),
                firstDay: CalendarDay(year: 2026, month: 10, day: 5),
                today: CalendarDay(year: 2026, month: 10, day: 7)
            )
        }

        @Test("目標を立てた日から1日の目安と比べ、立てる前の日は比べないこと")
        func comparesFromStartedDay() {
            #expect(timeline.days.map(\.ring.dailyGuide) == [nil, guide, guide])
        }
    }

    @Suite("目標が無いとき")
    struct NoGoal {
        @Test("どの日も1日の目安と比べないこと")
        func comparesNoDay() {
            let timeline = Timeline(
                input: Timeline.Input(
                    goalRecords: GoalRecords(
                        goals: [], dailyGuides: [], expenditureEstimates: [], weeklyReviews: [],
                        weightTrend: nil, weightRecords: []), rejectedLines: [], meals: [],
                    notices: [], undelivered: .none, conversation: .none),
                firstDay: CalendarDay(year: 2026, month: 10, day: 5),
                today: CalendarDay(year: 2026, month: 10, day: 6)
            )

            #expect(timeline.days.map(\.ring.dailyGuide) == [nil, nil])
        }
    }
}
