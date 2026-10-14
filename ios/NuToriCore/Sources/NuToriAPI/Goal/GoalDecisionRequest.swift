public import Foundation

/// 目標を決める要求。要求の ID は端末が振り、届いたか分からないときの再送で同じ ID を使う
public struct GoalDecisionRequest: Sendable, Equatable {
    public let requestId: UUID
    /// 目標案の応答で受け取った開始の日（YYYY-MM-DD）
    public let startedOn: String
    public let choice: Choice
    /// 見せていた目標体重（自分で決めたときはその目標体重）
    public let shownTargetWeightKilograms: Double
    public let shownDailyGuide: DailyGuidePlan
    /// この目標の設定のあいだに、端末が端の値に直した自分の目標体重の数
    public let rejectedCustomTargetWeightCount: Int

    public init(
        requestId: UUID,
        startedOn: String,
        choice: Choice,
        shownTargetWeightKilograms: Double,
        shownDailyGuide: DailyGuidePlan,
        rejectedCustomTargetWeightCount: Int
    ) {
        self.requestId = requestId
        self.startedOn = startedOn
        self.choice = choice
        self.shownTargetWeightKilograms = shownTargetWeightKilograms
        self.shownDailyGuide = shownDailyGuide
        self.rejectedCustomTargetWeightCount = rejectedCustomTargetWeightCount
    }

    public enum Choice: Sendable, Equatable {
        case maintain
        /// 期限は YYYY-MM-DD
        case proposal(
            direction: GoalProposals.Direction, deadlineOn: String, pace: GoalProposals.Pace)
        case custom(
            direction: GoalProposals.Direction, deadlineOn: String, targetWeightKilograms: Double)
    }
}
