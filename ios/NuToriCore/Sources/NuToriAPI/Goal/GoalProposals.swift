/// 目標案の答え。減量・増量は3つの枠と受け付ける幅、維持は目標体重と1日の目安
public struct GoalProposals: Sendable, Equatable {
    /// 開始の日（YYYY-MM-DD）。目標を決める要求に同じ日を載せる
    public let startedOn: String
    public let expenditureKilocalories: Int
    public let expenditureSource: ExpenditureSource
    /// 計算に使った開始の日の体重の傾向（丸めていない）
    public let startingWeightTrendKilograms: Double
    /// 体重の傾向の元になった最後の体重記録の日（YYYY-MM-DD）
    public let lastWeightRecordedOn: String
    public let plan: Plan

    public init(
        startedOn: String,
        expenditureKilocalories: Int,
        expenditureSource: ExpenditureSource,
        startingWeightTrendKilograms: Double,
        lastWeightRecordedOn: String,
        plan: Plan
    ) {
        self.startedOn = startedOn
        self.expenditureKilocalories = expenditureKilocalories
        self.expenditureSource = expenditureSource
        self.startingWeightTrendKilograms = startingWeightTrendKilograms
        self.lastWeightRecordedOn = lastWeightRecordedOn
        self.plan = plan
    }

    public enum ExpenditureSource: Sendable, Equatable {
        /// 最近4週の記録から逆算した
        case backCalculated
        /// 身体データの式で出した
        case formula
        /// 立て直すときの今の推定
        case current
    }

    public enum Plan: Sendable, Equatable {
        /// 減量・増量
        case weightChange(WeightChange)
        case maintenance(Maintenance)
    }

    public struct WeightChange: Sendable, Equatable {
        public let direction: Direction
        /// 期限（YYYY-MM-DD）
        public let deadlineOn: String
        /// ゆるめ・標準・ハードの3つの枠を、この順に
        public let proposals: [Proposal]
        /// 自分で決める目標体重の受け付ける幅。受け付ける目標体重が無ければ nil
        public let acceptedTargetWeightRange: AcceptedTargetWeightRange?

        public init(
            direction: Direction,
            deadlineOn: String,
            proposals: [Proposal],
            acceptedTargetWeightRange: AcceptedTargetWeightRange?
        ) {
            self.direction = direction
            self.deadlineOn = deadlineOn
            self.proposals = proposals
            self.acceptedTargetWeightRange = acceptedTargetWeightRange
        }

        /// 出せる案
        public var offeredProposals: [OfferedProposal] {
            proposals.compactMap {
                switch $0 {
                case .offered(let offered): offered
                case .unavailable: nil
                }
            }
        }
    }

    public enum Direction: Sendable, Equatable {
        case lose
        case gain
    }

    public enum Pace: String, Sendable, Equatable, CaseIterable {
        case gentle
        case standard
        case hard
    }

    /// 3つの枠の1つ。出せる案か、出せない枠
    public enum Proposal: Sendable, Equatable {
        case offered(OfferedProposal)
        case unavailable(pace: Pace, reason: UnavailableReason)

        public var pace: Pace {
            switch self {
            case .offered(let offered): offered.pace
            case .unavailable(let pace, _): pace
            }
        }
    }

    public struct OfferedProposal: Sendable, Equatable {
        public let pace: Pace
        public let targetWeightKilograms: Double
        public let dailyGuide: DailyGuidePlan
        /// 大変さ。案ではその案の段階
        public let difficulty: Pace
        /// 1日の目安と推定消費カロリーの差（50 kcal 単位。少ないときは負）
        public let dailyGuideDifferenceKilocalories: Int

        public init(
            pace: Pace,
            targetWeightKilograms: Double,
            dailyGuide: DailyGuidePlan,
            difficulty: Pace,
            dailyGuideDifferenceKilocalories: Int
        ) {
            self.pace = pace
            self.targetWeightKilograms = targetWeightKilograms
            self.dailyGuide = dailyGuide
            self.difficulty = difficulty
            self.dailyGuideDifferenceKilocalories = dailyGuideDifferenceKilocalories
        }
    }

    public enum UnavailableReason: Sendable, Equatable {
        /// 1日の目安が下限 1,200 kcal を下回る
        case dailyGuideBelowMinimum
        /// 端末が知らない理由
        case unknown(String)

        /// サーバーの `unavailableReason` の値
        var serverName: String {
            switch self {
            case .dailyGuideBelowMinimum: "daily_guide_below_minimum"
            case .unknown(let name): name
            }
        }

        /// 知らない値は `unknown` にする
        init(serverName: String) {
            switch serverName {
            case "daily_guide_below_minimum": self = .dailyGuideBelowMinimum
            default: self = .unknown(serverName)
            }
        }
    }

    public struct AcceptedTargetWeightRange: Sendable, Equatable {
        public let minimumKilograms: Double
        public let maximumKilograms: Double
        /// いちばん速い端（減量は下の端、増量は上の端）を決めた理由
        public let fastestEndReason: TargetWeightLimitReason

        public init(
            minimumKilograms: Double,
            maximumKilograms: Double,
            fastestEndReason: TargetWeightLimitReason
        ) {
            self.minimumKilograms = minimumKilograms
            self.maximumKilograms = maximumKilograms
            self.fastestEndReason = fastestEndReason
        }
    }

    public struct Maintenance: Sendable, Equatable {
        public let targetWeightKilograms: Double
        public let dailyGuide: DailyGuidePlan

        public init(targetWeightKilograms: Double, dailyGuide: DailyGuidePlan) {
            self.targetWeightKilograms = targetWeightKilograms
            self.dailyGuide = dailyGuide
        }
    }
}
