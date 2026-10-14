public import Foundation

/// 1日の目安。サーバーだけが書き、消えない。記録の ID は1日の目安の ID
public struct SyncedDailyGuide: Sendable, Equatable {
    public let id: UUID
    /// 目標の ID。目標より先に届くことがある
    public let goalId: UUID
    /// 計算に使った推定消費カロリーの ID。推定より先に届くことがある
    public let expenditureEstimateId: UUID
    /// 当てる始まりの日（YYYY-MM-DD）
    public let effectiveOn: String
    public let energyKilocalories: Int
    public let proteinGrams: Int
    public let fatGrams: Int
    public let carbohydrateGrams: Int
    /// 当たった上限と下限。当たったものだけが並ぶ
    public let limitHits: [LimitHit]

    public init(
        id: UUID,
        goalId: UUID,
        expenditureEstimateId: UUID,
        effectiveOn: String,
        energyKilocalories: Int,
        proteinGrams: Int,
        fatGrams: Int,
        carbohydrateGrams: Int,
        limitHits: [LimitHit]
    ) {
        self.id = id
        self.goalId = goalId
        self.expenditureEstimateId = expenditureEstimateId
        self.effectiveOn = effectiveOn
        self.energyKilocalories = energyKilocalories
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.limitHits = limitHits
    }

    /// サーバーの `limitHits` の値
    public enum LimitHit: String, Sendable, Equatable {
        /// 1週の変化の上限
        case weeklyChange = "weekly_change"
        /// 必要な速さの上限
        case requiredPace = "required_pace"
        /// 下限のエネルギー
        case minimumEnergy = "minimum_energy"
    }
}
