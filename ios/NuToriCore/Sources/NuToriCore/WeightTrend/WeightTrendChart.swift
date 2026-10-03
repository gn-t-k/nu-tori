import Foundation

/// 体重の画面の傾向のグラフに描くもの。横軸は今日までの最近4週で固定する
public struct WeightTrendChart: Hashable, Sendable {
    /// 横軸。27 日前から今日まで
    public let days: ClosedRange<CalendarDay>
    /// 4週の中の、日の代表値の点。送り待ちの記録も含め、日の順
    public let points: [Point]
    public let trendLine: TrendLine
    /// 使い始めた日が4週の中にあるときだけ、その日
    public let firstDayDivider: CalendarDay?

    /// - Parameters:
    ///   - weightRecords: キャッシュの体重記録（送り待ちを含む）
    ///   - trend: 届いた体重の傾向。体重記録が無ければ nil
    public init(
        weightRecords: [WeightRecord],
        trend: WeightTrend?,
        firstDay: CalendarDay,
        today: CalendarDay
    ) {
        let days = today.advanced(by: -27)...today
        let representativeWeights = RepresentativeWeight.daily(of: weightRecords)
        self.days = days
        points = representativeWeights.filter { days.contains($0.day) }.map {
            Point(
                day: $0.day, kilograms: $0.record.kilograms, isBeforeFirstDay: $0.day < firstDay)
        }
        trendLine =
            representativeWeights.count < WeightTrend.minimumRecordedDaysToShow
            ? .tooFewRecordedDays
            : .drawn(trend?.days.filter { days.contains($0.day) } ?? [])
        firstDayDivider = days.contains(firstDay) ? firstDay : nil
    }

    /// グラフの下に添える文。線を引くまでだけ出す
    public var note: String? {
        switch trendLine {
        case .drawn:
            nil
        case .tooFewRecordedDays:
            "点は測った体重。記録が増えると、傾向の線を引きます。"
        }
    }

    public struct Point: Hashable, Sendable {
        public let day: CalendarDay
        public let kilograms: Double
        /// 使い始める前の点は薄く描く
        public let isBeforeFirstDay: Bool

        public init(day: CalendarDay, kilograms: Double, isBeforeFirstDay: Bool) {
            self.day = day
            self.kilograms = kilograms
            self.isBeforeFirstDay = isBeforeFirstDay
        }
    }

    public enum TrendLine: Hashable, Sendable {
        /// 4週の中の、届いた傾向の日の値。傾向がまだ届いていなければ空
        case drawn([WeightTrend.Day])
        /// 記録のある日が足りず、あてにならない線を見せないために引かない
        case tooFewRecordedDays
    }
}
