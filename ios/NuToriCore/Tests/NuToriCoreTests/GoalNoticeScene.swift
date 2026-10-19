import Foundation
import NuToriCore
import Testing

/// 目標の知らせのタイムラインのテストで使う目標とタイムライン
enum GoalNoticeScene {
    static func losing(achievedAt: String, achievedDay: CalendarDay, closure: Goal.Closure? = nil)
        throws -> Goal
    {
        let losing = try Goal.losing()
        return Goal(
            id: losing.id, startedDay: losing.startedDay,
            startingWeightTrendKilograms: losing.startingWeightTrendKilograms,
            targetWeightKilograms: losing.targetWeightKilograms, decidedAt: losing.decidedAt,
            timeZone: losing.timeZone, direction: losing.direction,
            achievement: Goal.Achievement(
                achievedDay: achievedDay, judgedAt: try Date(achievedAt, strategy: .iso8601),
                timeZone: losing.timeZone),
            deadlineConfirmation: nil, closure: closure)
    }

    static func losing(
        confirmedAt: String, deadlineWeightTrendKilograms: Double, closure: Goal.Closure? = nil
    ) throws -> Goal {
        let losing = try Goal.losing()
        return Goal(
            id: losing.id, startedDay: losing.startedDay,
            startingWeightTrendKilograms: losing.startingWeightTrendKilograms,
            targetWeightKilograms: losing.targetWeightKilograms, decidedAt: losing.decidedAt,
            timeZone: losing.timeZone, direction: losing.direction, achievement: nil,
            deadlineConfirmation: Goal.DeadlineConfirmation(
                deadlineWeightTrendKilograms: deadlineWeightTrendKilograms,
                confirmedAt: try Date(confirmedAt, strategy: .iso8601), timeZone: losing.timeZone),
            closure: closure)
    }

    /// 使い始めた日は目標の開始の日（10月1日）
    static func timeline(goals: [Goal], weightRecords: [WeightRecord], today: CalendarDay)
        -> Timeline
    {
        Timeline(
            input: Timeline.Input(
                weightRecords: weightRecords, rejectedLines: [], meals: [], notices: [],
                undelivered: .none, conversation: .none, goals: goals, dailyGuides: [],
                weeklyReviews: [], expenditureEstimates: [], weightTrend: nil),
            firstDay: CalendarDay(year: 2026, month: 10, day: 1), today: today)
    }

    static func itemIds(on day: CalendarDay, in timeline: Timeline) -> [String] {
        timeline.days.first { $0.day == day }?.items.map(\.id) ?? []
    }

    static func notices(in timeline: Timeline) -> [GoalNotice] {
        timeline.days.flatMap(\.items).compactMap { item -> GoalNotice? in
            if case .goalNotice(let notice) = item { notice } else { nil }
        }
    }
}
