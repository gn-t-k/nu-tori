public import Foundation

/// 目標。サーバーだけが書き、消えない。記録の ID は目標の ID。閉じると、同じ目標の変更がもう一度届く
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
        closure: Closure?
    ) {
        self.id = id
        self.startedOn = startedOn
        self.startingWeightTrendKilograms = startingWeightTrendKilograms
        self.targetWeightKilograms = targetWeightKilograms
        self.decidedAt = decidedAt
        self.timeZone = timeZone
        self.direction = direction
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
            // swiftlint:disable:next no_default_in_switch - サーバーの名前は文字列で、知らない値が来る
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

    public struct Closure: Sendable, Equatable {
        /// 終わった日（YYYY-MM-DD）。次の目標の開始の日
        public let endedOn: String
        public let nextGoalId: UUID

        public init(endedOn: String, nextGoalId: UUID) {
            self.endedOn = endedOn
            self.nextGoalId = nextGoalId
        }
    }
}
