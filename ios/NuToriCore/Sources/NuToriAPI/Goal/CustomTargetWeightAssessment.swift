/// 自分で決める目標体重の答え
public struct CustomTargetWeightAssessment: Sendable, Equatable {
    /// 計算に使った開始の日（YYYY-MM-DD）
    public let startedOn: String
    public let outcome: Outcome

    public init(startedOn: String, outcome: Outcome) {
        self.startedOn = startedOn
        self.outcome = outcome
    }

    public enum Outcome: Sendable, Equatable {
        case accepted(Accepted)
        /// 受け付けるいちばん近い目標体重は、その期限に受け付ける目標体重が無ければ nil
        case rejected(
            reason: TargetWeightLimitReason, nearestAcceptedTargetWeightKilograms: Double?)
    }

    public struct Accepted: Sendable, Equatable {
        public let dailyGuide: DailyGuidePlan
        /// 大変さ。必要な速さを案の速さで区切った段階
        public let difficulty: GoalProposals.Pace
        /// 1日の目安と推定消費カロリーの差（50 kcal 単位。少ないときは負）
        public let dailyGuideDifferenceKilocalories: Int

        public init(
            dailyGuide: DailyGuidePlan,
            difficulty: GoalProposals.Pace,
            dailyGuideDifferenceKilocalories: Int
        ) {
            self.dailyGuide = dailyGuide
            self.difficulty = difficulty
            self.dailyGuideDifferenceKilocalories = dailyGuideDifferenceKilocalories
        }
    }
}
