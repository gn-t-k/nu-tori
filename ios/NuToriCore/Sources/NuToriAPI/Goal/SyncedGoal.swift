public import Foundation

/// 目標。サーバーだけが書き、消えない。記録の ID は目標の ID。達成する・期限の日を確定する・閉じると、同じ目標の変更がもう一度届く
public struct SyncedGoal: Sendable, Equatable {
    public let id: UUID
    /// 開始の日（YYYY-MM-DD）
    public let startedOn: String
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
        startedOn: String,
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
        self.startedOn = startedOn
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
    public enum Direction: Sendable, Equatable {
        case lose(WeightChange)
        case gain(WeightChange)
        case maintain

        /// サーバーの `direction` の値
        public var serverName: String {
            switch self {
            case .lose: "lose"
            case .gain: "gain"
            case .maintain: "maintain"
            }
        }

        public var weightChange: WeightChange? {
            switch self {
            case .lose(let weightChange), .gain(let weightChange): weightChange
            case .maintain: nil
            }
        }

        /// 知らない向きと、期限の無い減量・増量は nil。維持に付いた期限は読み飛ばす
        init?(serverName: String, weightChange: WeightChange?) {
            switch serverName {
            case "lose":
                guard let weightChange else { return nil }
                self = .lose(weightChange)
            case "gain":
                guard let weightChange else { return nil }
                self = .gain(weightChange)
            case "maintain":
                self = .maintain
            default:
                return nil
            }
        }
    }

    public struct WeightChange: Sendable, Equatable {
        /// 期限（YYYY-MM-DD）
        public let deadlineOn: String
        public let pacePlan: PacePlan

        public init(deadlineOn: String, pacePlan: PacePlan) {
            self.deadlineOn = deadlineOn
            self.pacePlan = pacePlan
        }
    }

    /// サーバーの `pacePlan` の値
    public enum PacePlan: String, Sendable, Equatable {
        case gentle
        case standard
        case hard
        /// 自分で決めた目標体重
        case custom
    }

    public struct Achievement: Sendable, Equatable {
        /// 達成した日（YYYY-MM-DD）
        public let achievedOn: String
        public let judgedAt: Date
        /// 達成を判定した要求のタイムゾーン
        public let timeZone: TimeZone

        public init(achievedOn: String, judgedAt: Date, timeZone: TimeZone) {
            self.achievedOn = achievedOn
            self.judgedAt = judgedAt
            self.timeZone = timeZone
        }
    }

    public struct DeadlineConfirmation: Sendable, Equatable {
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

    public struct Closure: Sendable, Equatable {
        /// 終わった日（YYYY-MM-DD）。次の目標の開始の日
        public let endedOn: String
        public let nextGoalId: UUID
        public let endReason: EndReason

        public init(endedOn: String, nextGoalId: UUID, endReason: EndReason) {
            self.endedOn = endedOn
            self.nextGoalId = nextGoalId
            self.endReason = endReason
        }
    }

    /// サーバーの `endReason` の値
    public enum EndReason: String, Sendable, Equatable {
        /// 立て直しによる切り替え
        case switched
        /// 期限後の維持に移った
        case movedToMaintenance = "moved_to_maintenance"
    }
}
