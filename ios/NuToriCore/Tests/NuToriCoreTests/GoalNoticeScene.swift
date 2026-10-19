import Foundation
import NuToriCore
import Testing

/// 目標の知らせのタイムラインのテストで使う目標とタイムライン
enum GoalNoticeScene {
    static func losing(achievedAt: String, achievedDay: CalendarDay, closure: Goal.Closure? = nil)
        throws -> Goal
    {
        try Goal.losing(
            achievement: .inTokyo(on: achievedDay, judgedAt: achievedAt), closure: closure)
    }

    static func losing(
        confirmedAt: String, deadlineWeightTrendKilograms: Double, closure: Goal.Closure? = nil
    ) throws -> Goal {
        try Goal.losing(
            deadlineConfirmation: .inTokyo(
                weightTrendKilograms: deadlineWeightTrendKilograms, confirmedAt: confirmedAt),
            closure: closure)
    }

    /// 使い始めた日は目標の開始の日（10月1日）
    static func timeline(goals: [Goal], weightRecords: [WeightRecord], today: CalendarDay)
        -> Timeline
    {
        Timeline(
            input: Timeline.Input(
                goalRecords: .fixture(goals: goals, weightRecords: weightRecords),
                rejectedLines: [], meals: [],
                notices: [], undelivered: .none, conversation: .none),
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
