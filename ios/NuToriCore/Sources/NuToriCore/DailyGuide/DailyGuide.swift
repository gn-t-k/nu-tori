public import Foundation

/// 1日の目安。サーバーだけが書き、消えない。
/// 目標より先に届くことがあるので、目標の ID を値で持つ（推定消費カロリーも同じ）
public struct DailyGuide: Hashable, Sendable {
    public let id: UUID
    public let goalId: UUID
    /// 計算に使った推定消費カロリー
    public let expenditureEstimateId: UUID
    /// 当てる始まりの日
    public let effectiveDay: CalendarDay
    public let energyKilocalories: Int
    public let proteinGrams: Int
    public let fatGrams: Int
    public let carbohydrateGrams: Int
    /// 当たった上限と下限。当たったものだけが並ぶ
    public let limitHits: [LimitHit]

    /// 1日の目安の下限。目安を出せない理由の文と、下限に当たった週の文に出す。正本はサーバーの `minimumDailyGuideEnergyKcal`
    public static let minimumEnergyKilocalories = 1200
    /// 見直しで前の週の1日の目安から変える量の上限（±）。上限に当たった週の文に出す。正本はサーバーの `maximumWeeklyChangeKcal`
    static let weeklyChangeLimitKilocalories = 150

    /// 必要な速さの上限（1週間に体重の何 % か）。上限に当たった週の文に出す
    static func requiredPaceLimitPercent(_ direction: Goal.Direction) -> Double {
        let rate =
            switch direction {
            case .lose: loseRequiredPaceLimitRate
            case .gain: gainRequiredPaceLimitRate
            case .maintain: maintainRequiredPaceLimitRate
            }
        return rate * 100
    }

    // scripts/check がサーバーの値と比べられるよう、% でなくサーバーと同じ割合で持つ
    /// 正本はサーバーの `weeklyPaceRates.lose.hard`
    private static let loseRequiredPaceLimitRate = 0.0075
    /// 正本はサーバーの `weeklyPaceRates.gain.hard`
    private static let gainRequiredPaceLimitRate = 0.005
    /// 正本はサーバーの `maintenanceWeeklyRate`
    private static let maintainRequiredPaceLimitRate = 0.0015

    public init(
        id: UUID,
        goalId: UUID,
        expenditureEstimateId: UUID,
        effectiveDay: CalendarDay,
        energyKilocalories: Int,
        proteinGrams: Int,
        fatGrams: Int,
        carbohydrateGrams: Int,
        limitHits: [LimitHit]
    ) {
        self.id = id
        self.goalId = goalId
        self.expenditureEstimateId = expenditureEstimateId
        self.effectiveDay = effectiveDay
        self.energyKilocalories = energyKilocalories
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.limitHits = limitHits
    }

    public enum LimitHit: Hashable, Sendable {
        /// 1週の変化の上限
        case weeklyChange
        /// 必要な速さの上限
        case requiredPace
        /// 下限のエネルギー
        case minimumEnergy
    }
}
