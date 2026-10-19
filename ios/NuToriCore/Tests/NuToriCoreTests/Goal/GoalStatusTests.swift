import Foundation
import NuToriCore
import Testing

@Suite("目標の状態")
struct GoalStatusTests {
    /// `Goal.losing()` に、達成・期限の日の確定・閉じたことを付けたもの
    static func losing(
        id: UUID = UUID(), achievedAt: String? = nil, confirmedAt: String? = nil,
        closure: Goal.Closure? = nil
    ) throws -> Goal {
        let losing = try Goal.losing()
        return Goal(
            id: id, startedDay: losing.startedDay,
            startingWeightTrendKilograms: losing.startingWeightTrendKilograms,
            targetWeightKilograms: losing.targetWeightKilograms, decidedAt: losing.decidedAt,
            timeZone: losing.timeZone, direction: losing.direction,
            achievement: try achievedAt.map {
                Goal.Achievement(
                    achievedDay: CalendarDay(year: 2026, month: 12, day: 10),
                    judgedAt: try Date($0, strategy: .iso8601), timeZone: losing.timeZone)
            },
            deadlineConfirmation: try confirmedAt.map {
                Goal.DeadlineConfirmation(
                    deadlineWeightTrendKilograms: 67.8,
                    confirmedAt: try Date($0, strategy: .iso8601), timeZone: losing.timeZone)
            },
            closure: closure)
    }

    @Test("今の目標が無ければ、目標がないこと")
    func noGoal() throws {
        let closed = try Self.losing(
            closure: Goal.Closure(
                endedDay: CalendarDay(year: 2026, month: 10, day: 20), nextGoalId: UUID(),
                endReason: .switched))

        #expect(GoalStatus(currentGoal: nil, goals: [closed]) == .noGoal)
    }

    @Test("達成も期限の日の確定も無い今の目標は、進行中であること")
    func inProgress() throws {
        let goal = try Self.losing()

        #expect(GoalStatus(currentGoal: goal, goals: [goal]) == .inProgress(goal))
    }

    @Test("達成した日だけがあれば、期限より前に達成したこと")
    func achievedBeforeDeadline() throws {
        let goal = try Self.losing(achievedAt: "2026-12-11T07:00:00+09:00")

        #expect(GoalStatus(currentGoal: goal, goals: [goal]) == .achievedBeforeDeadline(goal))
    }

    @Test("期限の日の確定だけがあれば、期限が来たこと")
    func deadlineReached() throws {
        let goal = try Self.losing(confirmedAt: "2026-12-25T07:00:00+09:00")

        #expect(GoalStatus(currentGoal: goal, goals: [goal]) == .deadlineReached(goal))
    }

    @Test("期限の日を確定したあとで達成しても、早いほうの期限が来たこと")
    func confirmedBeforeAchieved() throws {
        let goal = try Self.losing(
            achievedAt: "2026-12-27T07:00:00+09:00", confirmedAt: "2026-12-25T07:00:00+09:00")

        #expect(GoalStatus(currentGoal: goal, goals: [goal]) == .deadlineReached(goal))
    }

    @Test("達成したあとで期限の日を確定しても、早いほうの期限より前に達成したこと")
    func achievedBeforeConfirmed() throws {
        let goal = try Self.losing(
            achievedAt: "2026-12-11T07:00:00+09:00", confirmedAt: "2026-12-25T07:00:00+09:00")

        #expect(GoalStatus(currentGoal: goal, goals: [goal]) == .achievedBeforeDeadline(goal))
    }

    @Test("同じ要求で達成と確定をしたときは、期限より前に達成したこと")
    func achievedAndConfirmedAtOnce() throws {
        let goal = try Self.losing(
            achievedAt: "2026-12-25T07:00:00+09:00", confirmedAt: "2026-12-25T07:00:00+09:00")

        #expect(GoalStatus(currentGoal: goal, goals: [goal]) == .achievedBeforeDeadline(goal))
    }

    @Test("期限後の維持に移った前の目標があれば、期限後に選ばなかったこと")
    func maintainingAfterDeadline() throws {
        let maintenance = try Goal.maintaining()
        let previous = try Self.losing(
            confirmedAt: "2026-12-25T07:00:00+09:00",
            closure: Goal.Closure(
                endedDay: CalendarDay(year: 2026, month: 12, day: 28),
                nextGoalId: maintenance.id, endReason: .movedToMaintenance))

        #expect(
            GoalStatus(currentGoal: maintenance, goals: [previous, maintenance])
                == .maintainingAfterDeadline(maintenance, previous: previous))
    }

    @Test("立て直して切り替えた維持の目標は、進行中であること")
    func switchedMaintenanceIsInProgress() throws {
        let maintenance = try Goal.maintaining()
        let previous = try Self.losing(
            closure: Goal.Closure(
                endedDay: CalendarDay(year: 2026, month: 10, day: 20),
                nextGoalId: maintenance.id, endReason: .switched))

        #expect(
            GoalStatus(currentGoal: maintenance, goals: [previous, maintenance])
                == .inProgress(maintenance))
    }

    @Test("期限後の維持の目標を立て直して閉じたあとの目標は、進行中であること")
    func switchedFromMaintenanceIsInProgress() throws {
        let next = try Self.losing()
        let maintenance = try Goal.maintaining()
        let closedMaintenance = Goal(
            id: maintenance.id, startedDay: maintenance.startedDay,
            startingWeightTrendKilograms: maintenance.startingWeightTrendKilograms,
            targetWeightKilograms: maintenance.targetWeightKilograms,
            decidedAt: maintenance.decidedAt, timeZone: maintenance.timeZone,
            direction: maintenance.direction, achievement: nil, deadlineConfirmation: nil,
            closure: Goal.Closure(
                endedDay: CalendarDay(year: 2027, month: 1, day: 5), nextGoalId: next.id,
                endReason: .switched))
        let previous = try Self.losing(
            confirmedAt: "2026-12-25T07:00:00+09:00",
            closure: Goal.Closure(
                endedDay: CalendarDay(year: 2026, month: 12, day: 28),
                nextGoalId: maintenance.id, endReason: .movedToMaintenance))

        #expect(
            GoalStatus(currentGoal: next, goals: [previous, closedMaintenance, next])
                == .inProgress(next))
    }
}
