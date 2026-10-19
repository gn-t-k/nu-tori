import Foundation
import NuToriCore
import SwiftData

/// 目標。期限と速さの案（減量・増量だけ）と、閉じたこと（終わった日と次の目標）も同じ行に持つ
@Model
nonisolated final class CachedGoal {
    @Attribute(.unique) var goalId: UUID
    /// YYYY-MM-DD
    var startedDay: String
    var startingWeightTrendKilograms: Double
    var targetWeightKilograms: Double
    var decidedAt: Date
    var timeZoneIdentifier: String
    /// lose・gain・maintain
    var direction: String
    /// YYYY-MM-DD。減量・増量だけにある
    var deadlineDay: String?
    /// gentle・standard・hard・custom。減量・増量だけにある
    var pacePlan: String?
    /// YYYY-MM-DD。閉じた目標だけにある
    var endedDay: String?
    /// 閉じた目標だけにある
    var nextGoalId: UUID?

    init(_ goal: Goal) {
        goalId = goal.id
        startedDay = goal.startedDay.yearMonthDay
        startingWeightTrendKilograms = goal.startingWeightTrendKilograms
        targetWeightKilograms = goal.targetWeightKilograms
        decidedAt = goal.decidedAt
        timeZoneIdentifier = goal.timeZone.identifier
        direction = Self.stored(goal.direction)
        deadlineDay = goal.direction.weightChange?.deadlineDay.yearMonthDay
        pacePlan = goal.direction.weightChange.map { Self.stored($0.pacePlan) }
        endedDay = goal.closure?.endedDay.yearMonthDay
        nextGoalId = goal.closure?.nextGoalId
    }

    /// 届いた値にそろえる。閉じた目標は、同じ ID で届き直す
    func apply(_ goal: Goal) {
        startedDay = goal.startedDay.yearMonthDay
        startingWeightTrendKilograms = goal.startingWeightTrendKilograms
        targetWeightKilograms = goal.targetWeightKilograms
        decidedAt = goal.decidedAt
        timeZoneIdentifier = goal.timeZone.identifier
        direction = Self.stored(goal.direction)
        deadlineDay = goal.direction.weightChange?.deadlineDay.yearMonthDay
        pacePlan = goal.direction.weightChange.map { Self.stored($0.pacePlan) }
        endedDay = goal.closure?.endedDay.yearMonthDay
        nextGoalId = goal.closure?.nextGoalId
    }

    /// 読めない日付・タイムゾーン・向き・速さの案の行と、期限の無い減量・増量の行、次の目標の無い閉じた行は nil
    func goal() -> Goal? {
        guard let startedDay = CalendarDay(yearMonthDay: startedDay),
            let timeZone = TimeZone(identifier: timeZoneIdentifier),
            let direction = goalDirection()
        else {
            return nil
        }
        var closure: Goal.Closure?
        if endedDay != nil || nextGoalId != nil {
            guard let endedDay = endedDay.flatMap(CalendarDay.init(yearMonthDay:)), let nextGoalId
            else {
                return nil
            }
            closure = Goal.Closure(endedDay: endedDay, nextGoalId: nextGoalId)
        }
        return Goal(
            id: goalId, startedDay: startedDay,
            startingWeightTrendKilograms: startingWeightTrendKilograms,
            targetWeightKilograms: targetWeightKilograms, decidedAt: decidedAt,
            timeZone: timeZone, direction: direction, closure: closure)
    }

    private func goalDirection() -> Goal.Direction? {
        switch direction {
        case "lose": weightChange().map { .lose($0) }
        case "gain": weightChange().map { .gain($0) }
        case "maintain": .maintain
        // swiftlint:disable:next no_default_in_switch - 置き場の文字列は、知らない値を読めないとみなす
        default: nil
        }
    }

    private func weightChange() -> Goal.WeightChange? {
        guard let deadlineDay = deadlineDay.flatMap(CalendarDay.init(yearMonthDay:)) else {
            return nil
        }
        let plan: Goal.PacePlan? =
            switch pacePlan {
            case "gentle": .gentle
            case "standard": .standard
            case "hard": .hard
            case "custom": .custom
            // swiftlint:disable:next no_default_in_switch - 置き場の文字列は、知らない値を読めないとみなす
            default: nil
            }
        return plan.map { Goal.WeightChange(deadlineDay: deadlineDay, pacePlan: $0) }
    }

    private static func stored(_ direction: Goal.Direction) -> String {
        switch direction {
        case .lose: "lose"
        case .gain: "gain"
        case .maintain: "maintain"
        }
    }

    private static func stored(_ pacePlan: Goal.PacePlan) -> String {
        switch pacePlan {
        case .gentle: "gentle"
        case .standard: "standard"
        case .hard: "hard"
        case .custom: "custom"
        }
    }
}
