public import Foundation

/// 推定消費カロリー。サーバーだけが書き、消えない。記録の ID は推定の ID
public struct SyncedExpenditureEstimate: Sendable, Equatable {
    public let id: UUID
    /// 当てる始まりの日（YYYY-MM-DD）
    public let effectiveOn: String
    /// 1日の kcal
    public let expenditureKilocalories: Int
    public let estimatedAt: Date
    /// 推定の始まり（初めて目標を立てたときの推定）だけにある出どころ
    public let initialSource: InitialSource?

    public init(
        id: UUID,
        effectiveOn: String,
        expenditureKilocalories: Int,
        estimatedAt: Date,
        initialSource: InitialSource?
    ) {
        self.id = id
        self.effectiveOn = effectiveOn
        self.expenditureKilocalories = expenditureKilocalories
        self.estimatedAt = estimatedAt
        self.initialSource = initialSource
    }

    /// サーバーの `initialSource` の値
    public enum InitialSource: String, Sendable, Equatable {
        /// 食べた量と体重の変化からの逆算
        case backCalculated = "back_calculated"
        /// 身体データからの式
        case formula
    }
}
