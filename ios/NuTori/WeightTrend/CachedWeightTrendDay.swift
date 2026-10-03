import Foundation
import NuToriCore
import SwiftData

/// 体重の傾向の1日。並び全体が届くたびに、行をすべて置き換える
@Model
nonisolated final class CachedWeightTrendDay {
    /// YYYY-MM-DD
    @Attribute(.unique) var day: String
    /// 丸めない。見せるときに丸める
    var kilograms: Double

    init(_ trendDay: WeightTrend.Day) {
        day = trendDay.day.yearMonthDay
        kilograms = trendDay.kilograms
    }

    /// 読めない日付の行は nil
    func trendDay() -> WeightTrend.Day? {
        CalendarDay(yearMonthDay: day).map { WeightTrend.Day(day: $0, kilograms: kilograms) }
    }

    /// 並び全体が届くたびに置き換わるので、行をすべて日の順に並べる。行が無ければ傾向は無い
    static func weightTrend(of rows: [CachedWeightTrendDay]) -> WeightTrend? {
        let days = rows.compactMap { $0.trendDay() }.sorted { $0.day < $1.day }
        return days.isEmpty ? nil : WeightTrend(days: days)
    }
}
