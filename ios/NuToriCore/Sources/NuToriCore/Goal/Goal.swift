public import Foundation

/// 目標。サーバーだけが書き、消えない。立て直すか期限後の維持に移ると、前の目標は閉じて残る
public struct Goal: Hashable, Sendable {
    public let id: UUID
    /// 開始の日。目標が当たり始める日
    public let startedDay: CalendarDay
    /// 開始の日以前で最も新しい体重の傾向
    public let startingWeightTrendKilograms: Double
    public let targetWeightKilograms: Double
    public let decidedAt: Date
    /// 目標を決めたときのタイムゾーン
    public let timeZone: TimeZone
    public let direction: Direction
    /// 達成していなければ nil。減量・増量の目標だけに付く
    public let achievement: Achievement?
    /// 期限の日を確定していなければ nil。減量・増量の目標だけに付く
    public let deadlineConfirmation: DeadlineConfirmation?
    /// 閉じていなければ nil
    public let closure: Closure?

    public init(
        id: UUID,
        startedDay: CalendarDay,
        startingWeightTrendKilograms: Double,
        targetWeightKilograms: Double,
        decidedAt: Date,
        timeZone: TimeZone,
        direction: Direction,
        achievement: Achievement?,
        deadlineConfirmation: DeadlineConfirmation?,
        closure: Closure?
    ) {
        self.id = id
        self.startedDay = startedDay
        self.startingWeightTrendKilograms = startingWeightTrendKilograms
        self.targetWeightKilograms = targetWeightKilograms
        self.decidedAt = decidedAt
        self.timeZone = timeZone
        self.direction = direction
        self.achievement = achievement
        self.deadlineConfirmation = deadlineConfirmation
        self.closure = closure
    }

    /// 向き。期限と速さの案は、減量と増量だけが持つ
    public enum Direction: Hashable, Sendable {
        case lose(WeightChange)
        case gain(WeightChange)
        case maintain

        public var weightChange: WeightChange? {
            switch self {
            case .lose(let weightChange), .gain(let weightChange): weightChange
            case .maintain: nil
            }
        }
    }

    public struct WeightChange: Hashable, Sendable {
        /// 期限の日
        public let deadlineDay: CalendarDay
        public let pacePlan: PacePlan

        public init(deadlineDay: CalendarDay, pacePlan: PacePlan) {
            self.deadlineDay = deadlineDay
            self.pacePlan = pacePlan
        }
    }

    /// 速さの案
    public enum PacePlan: Hashable, Sendable {
        case gentle
        case standard
        case hard
        /// 自分で決めた目標体重
        case custom
    }

    public struct Achievement: Hashable, Sendable {
        /// 達成した日。体重の傾向が目標体重に届いた最初の日
        public let achievedDay: CalendarDay
        public let judgedAt: Date
        /// 達成を判定した要求のタイムゾーン
        public let timeZone: TimeZone

        public init(achievedDay: CalendarDay, judgedAt: Date, timeZone: TimeZone) {
            self.achievedDay = achievedDay
            self.judgedAt = judgedAt
            self.timeZone = timeZone
        }
    }

    /// 期限の日の結果の確定。確定のあとは、遅れて届いた体重でも変わらない
    public struct DeadlineConfirmation: Hashable, Sendable {
        /// 期限の日の体重の傾向
        public let deadlineWeightTrendKilograms: Double
        public let confirmedAt: Date
        /// 期限の日を確定した要求のタイムゾーン
        public let timeZone: TimeZone

        public init(deadlineWeightTrendKilograms: Double, confirmedAt: Date, timeZone: TimeZone) {
            self.deadlineWeightTrendKilograms = deadlineWeightTrendKilograms
            self.confirmedAt = confirmedAt
            self.timeZone = timeZone
        }
    }

    public struct Closure: Hashable, Sendable {
        /// 終わった日。次の目標の開始の日
        public let endedDay: CalendarDay
        public let nextGoalId: UUID
        public let endReason: EndReason

        public init(endedDay: CalendarDay, nextGoalId: UUID, endReason: EndReason) {
            self.endedDay = endedDay
            self.nextGoalId = nextGoalId
            self.endReason = endReason
        }
    }

    /// 終わり方
    public enum EndReason: Hashable, Sendable {
        /// 立て直しによる切り替え
        case switched
        /// 期限のあと次の目標が選ばれないまま、期限後の維持に移った。次の目標は期限後の維持の目標
        case movedToMaintenance
    }
}
