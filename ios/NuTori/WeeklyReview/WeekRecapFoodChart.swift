import Charts
import NuToriCore
import SwiftUI

/// 週の振り返りの食べた量の段のグラフ。日ごとの棒と、1日の目安の点線。記録の無い日は棒を描かず、読み上げだけ「記録なし」にする
struct WeekRecapFoodChart: View {
    let recap: WeekRecap

    var body: some View {
        Chart {
            ForEach(recap.days, id: \.day) { day in
                if let kilocalories = Self.kilocalories(day.food) {
                    BarMark(
                        x: .value("曜日", recap.monday.distance(to: day.day)),
                        y: .value("食べた量", kilocalories), width: .fixed(18)
                    )
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .accessibilityLabel(TimelineDayText.label(for: day.day))
                    .accessibilityValue(NutritionText.kilocalories(Int(kilocalories.rounded())))
                } else if day.food == .noMeals {
                    PointMark(
                        x: .value("曜日", recap.monday.distance(to: day.day)),
                        y: .value("食べた量", 0)
                    )
                    .symbolSize(0)
                    .accessibilityLabel(TimelineDayText.label(for: day.day))
                    .accessibilityValue("記録なし")
                }
            }
            if let dailyGuide = recap.dailyGuide {
                RuleMark(y: .value("1日の目安", dailyGuide.energyKilocalories))
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    .accessibilityLabel("1日の目安")
                    .accessibilityValue(NutritionText.kilocalories(dailyGuide.energyKilocalories))
            }
        }
        .chartXScale(domain: -0.5...6.5)
        .chartXAxis { WeekdayAxis.marks(monday: recap.monday) }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let kilocalories = value.as(Double.self) {
                        Text(NutritionText.number(.exactly(kilocalories), of: .energyKcal))
                            .font(.caption2)
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(height: 140)
        .padding(.vertical, 8)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    /// その日の食べた量（kcal）。食事が無い日と kcal が出ない日は nil
    private static func kilocalories(_ food: DayFood) -> Double? {
        food.figures?.totals[.energyKcal].value
    }
}
