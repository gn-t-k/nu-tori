public import Foundation

/// 推定消費カロリー。サーバーだけが書き、消えない
public struct ExpenditureEstimate: Hashable, Sendable {
    public let id: UUID
    /// 当てる始まりの日
    public let effectiveDay: CalendarDay
    /// 1日の kcal
    public let expenditureKilocalories: Int
    public let estimatedAt: Date
    /// 推定の始まり（初めて目標を立てたときの推定）だけにある出どころ
    public let initialSource: InitialSource?

    public init(
        id: UUID,
        effectiveDay: CalendarDay,
        expenditureKilocalories: Int,
        estimatedAt: Date,
        initialSource: InitialSource?
    ) {
        self.id = id
        self.effectiveDay = effectiveDay
        self.expenditureKilocalories = expenditureKilocalories
        self.estimatedAt = estimatedAt
        self.initialSource = initialSource
    }

    public enum InitialSource: Hashable, Sendable {
        /// 食べた量と体重の変化からの逆算
        case backCalculated
        /// 身体データからの式
        case formula
    }
}
