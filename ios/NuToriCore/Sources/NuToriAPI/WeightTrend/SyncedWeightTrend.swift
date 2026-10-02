/// 体重の傾向。サーバーだけが書く。取りに行くたびに並び全体が届くので、端末はキャッシュを置き換える
public struct SyncedWeightTrend: Sendable, Equatable {
    /// 始まり（最初の体重記録の日）から最後の体重記録の日まで、1日ずつ日の順
    public let days: [Day]

    public init(days: [Day]) {
        self.days = days
    }

    public struct Day: Sendable, Equatable {
        /// YYYY-MM-DD
        public let calendarDay: String
        /// 丸めない。見せるときに丸める
        public let trendKilograms: Double

        public init(calendarDay: String, trendKilograms: Double) {
            self.calendarDay = calendarDay
            self.trendKilograms = trendKilograms
        }
    }
}
