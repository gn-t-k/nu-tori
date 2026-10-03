/// 体重の傾向。サーバーが計算して、並び全体を届ける。体重記録が1つも無ければキャッシュに無い
public struct WeightTrend: Hashable, Sendable {
    /// 始まり（最初の体重記録の日）から最後の体重記録の日まで、1日ずつ日の順
    public let days: [Day]

    /// 傾向の線と速さを見せ始める、記録のある日（代表値のある日）の数。少ない記録の、あてにならない値を見せないため
    public static let minimumRecordedDaysToShow = 7

    public init(days: [Day]) {
        self.days = days
    }

    public struct Day: Hashable, Sendable {
        public let day: CalendarDay
        /// 丸めない。見せるときに丸める
        public let kilograms: Double

        public init(day: CalendarDay, kilograms: Double) {
            self.day = day
            self.kilograms = kilograms
        }
    }
}
