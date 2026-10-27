/// 日のまとめの目標の行。行の下の小さな文と、次の目標の行。
/// キャッシュの記録から組む（電波が無くても、届いている記録のままに見せるため）
public struct DaySummaryGoal: Hashable, Sendable {
    /// 目標の行の下の小さな文。「あと 2.8 kg・あと 68 日・間に合うペース」
    public let detail: String?
    /// 次の目標の行。今の目標が、達成・期限・期限後の維持のときだけ
    public let nextGoal: NextGoal?

    /// その日を含む目標が無ければ nil（今の「目標を立てる」のまま）
    /// - Parameters:
    ///   - day: 見ている日
    ///   - today: 端末の今のタイムゾーンでの今日
    public init?(day: CalendarDay, today: CalendarDay, records: GoalRecords) {
        guard
            let containing = DailyGuideForDay(
                on: day, goals: records.goals, dailyGuides: records.dailyGuides)?.goal
        else { return nil }
        // 過去の日は、その日を含む目標のその日の状態で書く。達成はその日までに達成した日だけ、期限の日の確定は期限の日が終わってから当てる
        let goal = Self.goal(containing, asOf: day)
        let status = GoalStatus(currentGoal: goal, goals: records.goals)
        detail = Self.detail(status: status, day: day, records: records)
        // 次の目標を選ぶ・立てる流れは今の目標を立て直すので、今の目標の日にだけ置く
        let isCurrent =
            CurrentGoal(today: today, goals: records.goals, dailyGuides: records.dailyGuides)?
            .goal.id == goal.id
        nextGoal =
            switch status {
            case .achievedBeforeDeadline, .deadlineReached: isCurrent ? .choose : nil
            case .maintainingAfterDeadline: isCurrent ? .set : nil
            case .noGoal, .inProgress: nil
            }
    }

    private static func goal(_ goal: Goal, asOf day: CalendarDay) -> Goal {
        let achievement = goal.achievement.flatMap { $0.achievedDay <= day ? $0 : nil }
        let deadlineConfirmation = goal.deadlineConfirmation.flatMap { confirmation in
            goal.direction.weightChange.map { day > $0.deadlineDay } == true ? confirmation : nil
        }
        return Goal(
            id: goal.id, startedDay: goal.startedDay,
            startingWeightTrendKilograms: goal.startingWeightTrendKilograms,
            targetWeightKilograms: goal.targetWeightKilograms, decidedAt: goal.decidedAt,
            timeZone: goal.timeZone, direction: goal.direction, achievement: achievement,
            deadlineConfirmation: deadlineConfirmation, closure: goal.closure)
    }

    private static func detail(status: GoalStatus, day: CalendarDay, records: GoalRecords)
        -> String?
    {
        switch status {
        case .noGoal:
            return nil
        case .inProgress(let goal):
            guard goal.direction.weightChange != nil else {
                return GoalStateText.keepingWithBand(goal, day: day, records: records)
            }
            let progress = GoalProgress(goal: goal, today: day, weightTrend: records.weightTrend)
            let pace = GoalStateText.pace(goal, day: day, records: records).flatMap(paceText)
            let parts = [progress?.text, pace].compactMap(\.self)
            return parts.isEmpty ? nil : parts.joined(separator: "・")
        case .achievedBeforeDeadline(let goal):
            return GoalStateText.achieved(goal)
        case .deadlineReached(let goal):
            return GoalStateText.deadlineReached(goal, records: records)
        case .maintainingAfterDeadline(let goal, _):
            return GoalStateText.keepingWithBand(goal, day: day, records: records)
        }
    }

    /// 進行中の減量・増量に添えるペース
    private static func paceText(_ pace: Pace) -> String? {
        switch pace {
        case .onTrack: "間に合うペース"
        case .behind(let shortfall, _, _): "期限に \(GoalText.kilograms(tenths: shortfall)) 届かない"
        case .inconclusive, .pending, .unavailable, .maintenance: nil
        }
    }

    public enum NextGoal: Hashable, Sendable {
        /// 達成・期限が来たときの「次の目標を選ぶ」
        case choose
        /// 期限後の維持の「次の目標を立てる」
        case set

        public var title: String {
            switch self {
            case .choose: "次の目標を選ぶ"
            case .set: "次の目標を立てる"
            }
        }
    }
}
