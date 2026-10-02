/// 日のまとめに出す、その日の体重の傾向の速さ（その日の傾向 − 7日前の傾向）
public struct WeightTrendSpeed: Hashable, Sendable {
    /// 0.1 kg 単位に丸めた速さ
    public let tenthsOfKilogram: Int

    /// その日と7日前の両方に傾向があり、その日までに記録のある日がそろっているときだけ作れる
    /// - Parameter weightRecords: キャッシュの体重記録（送り待ちを含む）
    public init?(on day: CalendarDay, trend: WeightTrend?, weightRecords: [WeightRecord]) {
        let recordedDayCount = RepresentativeWeight.daily(of: weightRecords).count {
            $0.day <= day
        }
        guard recordedDayCount >= WeightTrend.minimumRecordedDaysToShow,
            let trendDays = trend?.days,
            let current = trendDays.first(where: { $0.day == day }),
            let weekAgo = trendDays.first(where: { $0.day == day.advanced(by: -7) })
        else {
            return nil
        }
        tenthsOfKilogram = Int(((current.kilograms - weekAgo.kilograms) * 10).rounded())
    }

    /// 「1週間で −0.2 kg」の形
    public var text: String {
        let sign =
            if tenthsOfKilogram > 0 {
                "+"
            } else if tenthsOfKilogram < 0 {
                "−"
            } else {
                "±"
            }
        let magnitude = abs(tenthsOfKilogram)
        return "1週間で \(sign)\(magnitude / 10).\(magnitude % 10) kg"
    }
}
