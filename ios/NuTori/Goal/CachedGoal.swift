import Foundation
import NuToriCore
import SwiftData

/// 目標。期限と速さの案（減量・増量だけ）、達成と期限の日の確定（減量・増量だけ）、閉じたこと（終わった日と次の目標と終わり方）も同じ行に持つ
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
    /// switched・moved_to_maintenance。閉じた目標だけにある
    var endReason: String?
    /// YYYY-MM-DD。達成した目標だけにある
    var achievedDay: String?
    /// 達成した目標だけにある
    var achievementJudgedAt: Date?
    /// 達成した目標だけにある
    var achievementTimeZoneIdentifier: String?
    /// 期限の日を確定した目標だけにある
    var deadlineWeightTrendKilograms: Double?
    /// 期限の日を確定した目標だけにある
    var deadlineConfirmedAt: Date?
    /// 期限の日を確定した目標だけにある
    var deadlineConfirmationTimeZoneIdentifier: String?

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
        endReason = goal.closure.map { Self.stored($0.endReason) }
        achievedDay = goal.achievement?.achievedDay.yearMonthDay
        achievementJudgedAt = goal.achievement?.judgedAt
        achievementTimeZoneIdentifier = goal.achievement?.timeZone.identifier
        deadlineWeightTrendKilograms = goal.deadlineConfirmation?.deadlineWeightTrendKilograms
        deadlineConfirmedAt = goal.deadlineConfirmation?.confirmedAt
        deadlineConfirmationTimeZoneIdentifier = goal.deadlineConfirmation?.timeZone.identifier
    }

    /// 届いた値にそろえる。達成した・期限の日を確定した・閉じた目標は、同じ ID で届き直す
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
        endReason = goal.closure.map { Self.stored($0.endReason) }
        achievedDay = goal.achievement?.achievedDay.yearMonthDay
        achievementJudgedAt = goal.achievement?.judgedAt
        achievementTimeZoneIdentifier = goal.achievement?.timeZone.identifier
        deadlineWeightTrendKilograms = goal.deadlineConfirmation?.deadlineWeightTrendKilograms
        deadlineConfirmedAt = goal.deadlineConfirmation?.confirmedAt
        deadlineConfirmationTimeZoneIdentifier = goal.deadlineConfirmation?.timeZone.identifier
    }

    /// 読めない日付・タイムゾーン・向き・速さの案・終わり方の行と、期限の無い減量・増量の行、
    /// 閉じたこと・達成・期限の日の確定の値の一部だけがある行は nil
    func goal() -> Goal? {
        guard let startedDay = CalendarDay(yearMonthDay: startedDay),
            let timeZone = TimeZone(identifier: timeZoneIdentifier),
            let direction = goalDirection()
        else {
            return nil
        }
        var closure: Goal.Closure?
        if endedDay != nil || nextGoalId != nil || endReason != nil {
            guard let endedDay = endedDay.flatMap(CalendarDay.init(yearMonthDay:)), let nextGoalId,
                let endReason = goalEndReason()
            else {
                return nil
            }
            closure = Goal.Closure(endedDay: endedDay, nextGoalId: nextGoalId, endReason: endReason)
        }
        var achievement: Goal.Achievement?
        if achievedDay != nil || achievementJudgedAt != nil || achievementTimeZoneIdentifier != nil
        {
            guard let achievedDay = achievedDay.flatMap(CalendarDay.init(yearMonthDay:)),
                let achievementJudgedAt,
                let timeZone = achievementTimeZoneIdentifier.flatMap(TimeZone.init(identifier:))
            else {
                return nil
            }
            achievement = Goal.Achievement(
                achievedDay: achievedDay, judgedAt: achievementJudgedAt, timeZone: timeZone)
        }
        var deadlineConfirmation: Goal.DeadlineConfirmation?
        if deadlineWeightTrendKilograms != nil || deadlineConfirmedAt != nil
            || deadlineConfirmationTimeZoneIdentifier != nil
        {
            guard let deadlineWeightTrendKilograms, let deadlineConfirmedAt,
                let timeZone = deadlineConfirmationTimeZoneIdentifier.flatMap(
                    TimeZone.init(identifier:))
            else {
                return nil
            }
            deadlineConfirmation = Goal.DeadlineConfirmation(
                deadlineWeightTrendKilograms: deadlineWeightTrendKilograms,
                confirmedAt: deadlineConfirmedAt, timeZone: timeZone)
        }
        return Goal(
            id: goalId, startedDay: startedDay,
            startingWeightTrendKilograms: startingWeightTrendKilograms,
            targetWeightKilograms: targetWeightKilograms, decidedAt: decidedAt,
            timeZone: timeZone, direction: direction, achievement: achievement,
            deadlineConfirmation: deadlineConfirmation, closure: closure)
    }

    private func goalEndReason() -> Goal.EndReason? {
        switch endReason {
        case "switched": .switched
        case "moved_to_maintenance": .movedToMaintenance
        default: nil
        }
    }

    private func goalDirection() -> Goal.Direction? {
        switch direction {
        case "lose": weightChange().map { .lose($0) }
        case "gain": weightChange().map { .gain($0) }
        case "maintain": .maintain
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

    private static func stored(_ endReason: Goal.EndReason) -> String {
        switch endReason {
        case .switched: "switched"
        case .movedToMaintenance: "moved_to_maintenance"
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
