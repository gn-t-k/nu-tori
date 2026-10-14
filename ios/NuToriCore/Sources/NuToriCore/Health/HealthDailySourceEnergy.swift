/// 1つの出どころ（アプリ）が、1日に書いた摂取エネルギーの合計
public struct HealthDailySourceEnergy: Sendable, Equatable {
    public let day: CalendarDay
    public let sourceBundleId: String
    public let kilocalories: Double

    public init(day: CalendarDay, sourceBundleId: String, kilocalories: Double) {
        self.day = day
        self.sourceBundleId = sourceBundleId
        self.kilocalories = kilocalories
    }
}
