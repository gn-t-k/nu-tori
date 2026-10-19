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
    /// 目標体重の線。目標がなければ nil
    public let target: Target?
    /// 縦軸。4週の点と線が収まる、整数の kg で区切った範囲。維持は保つ幅が入るまで広げる
    public let kilogramsRange: ClosedRange<Double>

    /// - Parameters:
    ///   - weightRecords: キャッシュの体重記録（送り待ちを含む）
    ///   - trend: 届いた体重の傾向。体重記録が無ければ nil
    ///   - goal: 今の目標。無ければ nil
    public init(
        weightRecords: [WeightRecord],
        trend: WeightTrend?,
        firstDay: CalendarDay,
        today: CalendarDay,
        goal: Goal?
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
        let recorded = points.map(\.kilograms) + trendLine.days.map(\.kilograms)
        guard let goal else {
            target = nil
            kilogramsRange = Self.range(containing: recorded)
            return
        }
        let targetKilograms = goal.targetWeightKilograms
        if goal.direction.weightChange == nil {
            // 縦軸は保つ幅が入るまで広げる
            let band = Self.maintenanceBandKilograms
            target = .band(kilograms: targetKilograms, halfWidthKilograms: band)
            kilogramsRange = Self.range(
                containing: recorded + [targetKilograms - band, targetKilograms + band])
            return
        }
        // 縦軸は4週の記録の幅のまま。目標が遠くても、4週の変化が平らに見えないようにするため。点がまだ無ければ目標体重のまわりにする
        let range = Self.range(containing: recorded.isEmpty ? [targetKilograms] : recorded)
        kilogramsRange = range
        target =
            range.contains(targetKilograms)
            ? .line(kilograms: targetKilograms)
            : .beyondRange(kilograms: targetKilograms, isAbove: targetKilograms > range.upperBound)
    }

    /// 値が収まる、整数の kg で区切った範囲。狭すぎると揺れが大きく見えるので 2 kg は取る
    private static func range(containing values: [Double]) -> ClosedRange<Double> {
        guard let minimum = values.min(), let maximum = values.max() else {
            return 0...2
        }
        // 0.1 kg に丸めてから区切る。浮動小数の誤差で、ちょうど整数の値を1つ下の kg へ広げないため
        let lower = (((minimum - 0.3) * 10).rounded() / 10).rounded(.down)
        let upper = max((((maximum + 0.3) * 10).rounded() / 10).rounded(.up), lower + 2)
        return lower...upper
    }

    /// 保つ幅。ペースの維持と同じ ±0.7 kg
    private static let maintenanceBandKilograms = 0.7

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

        /// 引く線の日。引かなければ空
        public var days: [WeightTrend.Day] {
            switch self {
            case .drawn(let days): days
            case .tooFewRecordedDays: []
            }
        }
    }

    /// 目標体重の線
    public enum Target: Hashable, Sendable {
        /// 縦軸に入るので、点線を引く
        case line(kilograms: Double)
        /// 縦軸に入らないので、上か下の端に矢印を置く
        case beyondRange(kilograms: Double, isAbove: Bool)
        /// 維持。保つ幅を薄く塗り、点線を引く
        case band(kilograms: Double, halfWidthKilograms: Double)

        /// 「目標 70.0」「↓ 目標 70.0 kg」「保つ 72.0」
        public var label: String {
            switch self {
            case .line(let kilograms):
                "目標 \(Self.number(kilograms))"
            case .beyondRange(let kilograms, let isAbove):
                "\(isAbove ? "↑" : "↓") 目標 \(WeightAmountText.kilograms(kilograms))"
            case .band(let kilograms, _):
                "保つ \(Self.number(kilograms))"
            }
        }

        /// 単位を付けない「70.0」
        private static func number(_ kilograms: Double) -> String {
            let tenths = Int((kilograms * 10).rounded())
            return "\(tenths / 10).\(tenths % 10)"
        }
    }
}
