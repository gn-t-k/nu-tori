/// 目標案の要求で選んだ向きと期限。維持は期限を持たない
public enum GoalProposalsPlan: Sendable, Equatable {
    case maintain
    /// 期限は YYYY-MM-DD
    case weightChange(direction: GoalProposals.Direction, deadlineOn: String)
}
