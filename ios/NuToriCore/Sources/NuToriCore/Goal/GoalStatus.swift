/// 目標の状態。タイムライン・日のまとめ・体重の画面・目標の画面の見え方を分ける。
/// 今の目標の記録から端末が出す（電波が無くても、届いている記録のままに見せるため）
public enum GoalStatus: Hashable, Sendable {
    case noGoal
    case inProgress(Goal)
    /// 期限の日を確定する前に達成した。次の目標が選ばれるまで今の目標を続ける
    case achievedBeforeDeadline(Goal)
    /// 達成する前に期限の日を確定した。次の目標が選ばれるまで今の目標を続ける
    case deadlineReached(Goal)
    /// 期限のあと次の目標を選ばないまま、期限後の維持に移った。`previous` は期限を迎えた前の目標
    case maintainingAfterDeadline(Goal, previous: Goal)

    /// 達成と期限の日の確定の両方があれば、判定した時刻と確定した時刻の早いほう1つにする。
    /// 同じ時刻なら、同じ要求で体重記録を当てて達成を判定してから期限の日を確定したので、達成にする
    /// - Parameters:
    ///   - currentGoal: 今の目標（`CurrentGoal`）。無ければ nil
    ///   - goals: 閉じた目標も含む。期限後の維持の目標かは、前の目標の終わり方で決める
    public init(currentGoal: Goal?, goals: [Goal]) {
        guard let goal = currentGoal else {
            self = .noGoal
            return
        }
        if let previous = goal.goalMovedToMaintenance(from: goals) {
            self = .maintainingAfterDeadline(goal, previous: previous)
            return
        }
        switch (goal.achievement, goal.deadlineConfirmation) {
        case (let achievement?, let confirmation?):
            self =
                achievement.judgedAt <= confirmation.confirmedAt
                ? .achievedBeforeDeadline(goal) : .deadlineReached(goal)
        case (.some, nil):
            self = .achievedBeforeDeadline(goal)
        case (nil, .some):
            self = .deadlineReached(goal)
        case (nil, nil):
            self = .inProgress(goal)
        }
    }
}
