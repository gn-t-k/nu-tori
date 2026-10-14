public import Foundation

/// 目標。サーバーだけが書き、消えない。立て直すと、前の目標は閉じて残る
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
        closure: Closure?
    ) {
        self.id = id
        self.startedDay = startedDay
        self.startingWeightTrendKilograms = startingWeightTrendKilograms
        self.targetWeightKilograms = targetWeightKilograms
        self.decidedAt = decidedAt
        self.timeZone = timeZone
        self.direction = direction
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

    public struct Closure: Hashable, Sendable {
        /// 終わった日。次の目標の開始の日
        public let endedDay: CalendarDay
        public let nextGoalId: UUID

        public init(endedDay: CalendarDay, nextGoalId: UUID) {
            self.endedDay = endedDay
            self.nextGoalId = nextGoalId
        }
    }
}
