public import Foundation

/// 目標の達成・期限・期限後の維持の知らせ。同期で届いた目標の記録から描き、答えを持たない（帯の下の1行に出さない）。
/// 達成と期限は、1つの目標に判定した時刻と確定した時刻の早いほう1つだけを出す
public struct GoalNotice: Hashable, Sendable {
    /// 知らせの目標。期限後の維持の知らせなら、維持の目標
    public let goal: Goal
    public let kind: Kind
    /// 知らせの目標が今の目標でなくなったときの終わり方。今の目標なら nil で、ボタンを押せる
    public let unavailability: Goal.EndReason?

    public init(goal: Goal, kind: Kind, unavailability: Goal.EndReason?) {
        self.goal = goal
        self.kind = kind
        self.unavailability = unavailability
    }

    public enum Kind: Hashable, Sendable {
        case achieved(Goal.Achievement)
        case deadlineReached(Goal.DeadlineConfirmation)
        /// `previous` は期限を迎えた前の目標
        case movedToMaintenance(previous: Goal)

        /// タイムラインの項目の ID に入れる
        var idPrefix: String {
            switch self {
            case .achieved: "achieved"
            case .deadlineReached: "deadline"
            case .movedToMaintenance: "maintenance"
            }
        }
    }

    /// 達成は判定した時刻、期限は確定した時刻、期限後の維持は維持の目標を決めた時刻
    public var issuedAt: Date {
        switch kind {
        case .achieved(let achievement): achievement.judgedAt
        case .deadlineReached(let confirmation): confirmation.confirmedAt
        case .movedToMaintenance: goal.decidedAt
        }
    }

    /// 置く日を決めるタイムゾーン
    public var timeZone: TimeZone {
        switch kind {
        case .achieved(let achievement): achievement.timeZone
        case .deadlineReached(let confirmation): confirmation.timeZone
        case .movedToMaintenance: goal.timeZone
        }
    }

    public var headline: String {
        switch kind {
        case .achieved: "目標を達成しました"
        case .deadlineReached: "期限の\(deadlineText(of: goal))を迎えました"
        case .movedToMaintenance: "今の体重を保つ目標に切り替えました"
        }
    }

    public var body: String {
        switch kind {
        case .achieved(let achievement):
            let daysEarly =
                goal.direction.weightChange.map {
                    achievement.achievedDay.distance(to: $0.deadlineDay)
                } ?? 0
            return daysEarly > 0
                ? "期限の\(deadlineText(of: goal))より \(daysEarly) 日早く届きました。次の目標を選ぶまで、今の目標を続けます。"
                : "期限の\(deadlineText(of: goal))に届きました。次の目標を選ぶまで、今の目標を続けます。"
        case .deadlineReached(let confirmation):
            let result = DeadlineResult(goal: goal, confirmation: confirmation)
            let monday = goal.direction.weightChange.map {
                Self.maintenanceMonday(afterDeadline: $0.deadlineDay)
            }
            return (result.map { "\($0.text) でした。" } ?? "")
                + (monday.map {
                    "選ばなければ、\(GoalText.monthDay($0))（月）から今の体重を保つ目標で続けます。"
                } ?? "")
        case .movedToMaintenance(let previous):
            return
                "\(deadlineText(of: previous))の期限のあと次の目標を選ばなかったので、\(WeightAmountText.kilograms(goal.targetWeightKilograms)) を保つ目標で続けています。"
        }
    }

    /// 押すと、立て直す流れを開く
    public var actionTitle: String {
        switch kind {
        case .achieved, .deadlineReached: "次の目標を選ぶ"
        case .movedToMaintenance: "次の目標を立てる"
        }
    }

    /// ボタンから立て直す流れを開いたところ（`goal_setup_opened`）
    public var setupEntry: GoalSetupObservation.Entry {
        switch kind {
        case .achieved, .deadlineReached: .chooseNextGoal
        case .movedToMaintenance: .setNextGoal
        }
    }

    /// ボタンを押せないときに、すぐ下に添える理由
    public var unavailableText: String? {
        unavailability.map {
            switch $0 {
            case .switched: "次の目標を決めたので、ここからは選べません。"
            case .movedToMaintenance: "今の体重を保つ目標に切り替わったので、ここからは選べません。"
            }
        }
    }

    /// 目標の記録から出す知らせ。古い目標から順に
    /// - Parameters:
    ///   - goals: 閉じた目標も含む
    ///   - currentGoalId: 今の目標（`CurrentGoal`）の ID。無ければ nil
    static func notices(goals: [Goal], currentGoalId: UUID?) -> [GoalNotice] {
        goals.flatMap { goal -> [GoalNotice] in
            let unavailability = goal.id == currentGoalId ? nil : goal.closure?.endReason
            var kinds: [Kind] = []
            switch (goal.achievement, goal.deadlineConfirmation) {
            case (let achievement?, let confirmation?):
                // 同じ時刻なら、同じ要求で達成を判定してから期限の日を確定したので、達成にする（`GoalStatus` と同じ）
                kinds.append(
                    achievement.judgedAt <= confirmation.confirmedAt
                        ? .achieved(achievement) : .deadlineReached(confirmation))
            case (let achievement?, nil): kinds.append(.achieved(achievement))
            case (nil, let confirmation?): kinds.append(.deadlineReached(confirmation))
            case (nil, nil): break
            }
            if let previous = goal.goalMovedToMaintenance(from: goals) {
                kinds.append(.movedToMaintenance(previous: previous))
            }
            return kinds.map { GoalNotice(goal: goal, kind: $0, unavailability: unavailability) }
        }
    }

    /// 期限の日より後の最初の月曜。期限のあと次の目標を選ばなければ、この日から期限後の維持に移る
    private static func maintenanceMonday(afterDeadline deadlineDay: CalendarDay) -> CalendarDay {
        let nextDay = deadlineDay.advanced(by: 1)
        return nextDay.startOfWeek == nextDay ? nextDay : nextDay.startOfWeek.advanced(by: 7)
    }

    private func deadlineText(of goal: Goal) -> String {
        goal.direction.weightChange.map { GoalText.monthDay($0.deadlineDay) } ?? ""
    }
}
