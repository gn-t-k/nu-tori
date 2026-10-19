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
        try Goal.losing(
            id: id,
            achievement: try achievedAt.map {
                try .inTokyo(on: CalendarDay(year: 2026, month: 12, day: 10), judgedAt: $0)
            },
            deadlineConfirmation: try confirmedAt.map {
                try .inTokyo(weightTrendKilograms: 67.8, confirmedAt: $0)
            },
            closure: closure)
    }

    @Suite("今の目標が無いとき")
    struct NoCurrentGoal {
        let status: GoalStatus

        init() throws {
            let closed = try GoalStatusTests.losing(
                closure: Goal.Closure(
                    endedDay: CalendarDay(year: 2026, month: 10, day: 20), nextGoalId: UUID(),
                    endReason: .switched))
            status = GoalStatus(currentGoal: nil, goals: [closed])
        }

        @Test("目標がないこと")
        func isNoGoal() {
            #expect(status == .noGoal)
        }
    }

    @Suite("今の目標に達成も期限の日の確定も無いとき")
    struct NeitherAchievedNorConfirmed {
        let goal: Goal
        let status: GoalStatus

        init() throws {
            goal = try GoalStatusTests.losing()
            status = GoalStatus(currentGoal: goal, goals: [goal])
        }

        @Test("進行中であること")
        func isInProgress() {
            #expect(status == .inProgress(goal))
        }
    }

    @Suite("達成した日だけがあるとき")
    struct OnlyAchieved {
        let goal: Goal
        let status: GoalStatus

        init() throws {
            goal = try GoalStatusTests.losing(achievedAt: "2026-12-11T07:00:00+09:00")
            status = GoalStatus(currentGoal: goal, goals: [goal])
        }

        @Test("期限より前に達成したこと")
        func isAchievedBeforeDeadline() {
            #expect(status == .achievedBeforeDeadline(goal))
        }
    }

    @Suite("期限の日の確定だけがあるとき")
    struct OnlyConfirmed {
        let goal: Goal
        let status: GoalStatus

        init() throws {
            goal = try GoalStatusTests.losing(confirmedAt: "2026-12-25T07:00:00+09:00")
            status = GoalStatus(currentGoal: goal, goals: [goal])
        }

        @Test("期限が来たこと")
        func isDeadlineReached() {
            #expect(status == .deadlineReached(goal))
        }
    }

    @Suite("期限の日を確定したあとで達成したとき")
    struct ConfirmedBeforeAchieved {
        let goal: Goal
        let status: GoalStatus

        init() throws {
            goal = try GoalStatusTests.losing(
                achievedAt: "2026-12-27T07:00:00+09:00", confirmedAt: "2026-12-25T07:00:00+09:00")
            status = GoalStatus(currentGoal: goal, goals: [goal])
        }

        @Test("早いほうの期限が来たこと")
        func isDeadlineReached() {
            #expect(status == .deadlineReached(goal))
        }
    }

    @Suite("達成したあとで期限の日を確定したとき")
    struct AchievedBeforeConfirmed {
        let goal: Goal
        let status: GoalStatus

        init() throws {
            goal = try GoalStatusTests.losing(
                achievedAt: "2026-12-11T07:00:00+09:00", confirmedAt: "2026-12-25T07:00:00+09:00")
            status = GoalStatus(currentGoal: goal, goals: [goal])
        }

        @Test("早いほうの期限より前に達成したこと")
        func isAchievedBeforeDeadline() {
            #expect(status == .achievedBeforeDeadline(goal))
        }
    }

    @Suite("同じ要求で達成と確定をしたとき")
    struct AchievedAndConfirmedAtOnce {
        let goal: Goal
        let status: GoalStatus

        init() throws {
            goal = try GoalStatusTests.losing(
                achievedAt: "2026-12-25T07:00:00+09:00", confirmedAt: "2026-12-25T07:00:00+09:00")
            status = GoalStatus(currentGoal: goal, goals: [goal])
        }

        @Test("期限より前に達成したこと")
        func isAchievedBeforeDeadline() {
            #expect(status == .achievedBeforeDeadline(goal))
        }
    }

    @Suite("期限後の維持に移った前の目標があるとき")
    struct MovedToMaintenance {
        let maintenance: Goal
        let previous: Goal
        let status: GoalStatus

        init() throws {
            maintenance = try Goal.maintaining()
            previous = try GoalStatusTests.losing(
                confirmedAt: "2026-12-25T07:00:00+09:00",
                closure: Goal.Closure(
                    endedDay: CalendarDay(year: 2026, month: 12, day: 28),
                    nextGoalId: maintenance.id, endReason: .movedToMaintenance))
            status = GoalStatus(currentGoal: maintenance, goals: [previous, maintenance])
        }

        @Test("期限後に選ばなかったこと")
        func isMaintainingAfterDeadline() {
            #expect(status == .maintainingAfterDeadline(maintenance, previous: previous))
        }
    }

    @Suite("立て直して維持の目標に切り替えたとき")
    struct SwitchedToMaintenance {
        let maintenance: Goal
        let status: GoalStatus

        init() throws {
            maintenance = try Goal.maintaining()
            let previous = try GoalStatusTests.losing(
                closure: Goal.Closure(
                    endedDay: CalendarDay(year: 2026, month: 10, day: 20),
                    nextGoalId: maintenance.id, endReason: .switched))
            status = GoalStatus(currentGoal: maintenance, goals: [previous, maintenance])
        }

        @Test("維持の目標が進行中であること")
        func isInProgress() {
            #expect(status == .inProgress(maintenance))
        }
    }

    @Suite("期限後の維持の目標を立て直して閉じたとき")
    struct SwitchedFromMaintenance {
        let next: Goal
        let status: GoalStatus

        init() throws {
            next = try GoalStatusTests.losing()
            let maintenance = try Goal.maintaining()
            let closedMaintenance = try Goal.maintaining(
                id: maintenance.id,
                closure: Goal.Closure(
                    endedDay: CalendarDay(year: 2027, month: 1, day: 5), nextGoalId: next.id,
                    endReason: .switched))
            let previous = try GoalStatusTests.losing(
                confirmedAt: "2026-12-25T07:00:00+09:00",
                closure: Goal.Closure(
                    endedDay: CalendarDay(year: 2026, month: 12, day: 28),
                    nextGoalId: maintenance.id, endReason: .movedToMaintenance))
            status = GoalStatus(currentGoal: next, goals: [previous, closedMaintenance, next])
        }

        @Test("あとの目標が進行中であること")
        func isInProgress() {
            #expect(status == .inProgress(next))
        }
    }
}
