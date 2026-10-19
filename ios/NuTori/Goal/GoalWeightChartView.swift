import Charts
import NuToriCore
import SwiftUI

/// 目標の画面の体重の傾向のグラフ。横軸は開始の日から期限の日まで（維持は今日まで）。
/// 開始→目標の道筋は点線、傾向は Primary の線（DESIGN.md の「グラフ」）。使い始める前の記録は出さない（`gpre` A）
struct GoalWeightChartView: View {
    let chart: GoalOverview.WeightChart
    let goal: Goal

    var body: some View {
        Chart {
            ForEach(pathPoints, id: \.offset) { point in
                LineMark(
                    x: .value("日", point.offset), y: .value("目標の道筋", point.kilograms),
                    series: .value("線", "目標の道筋")
                )
                .foregroundStyle(Color(.secondaryLabel))
                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                .accessibilityHidden(true)
            }
            ForEach(chart.trend, id: \.day) { trendDay in
                LineMark(
                    x: .value("日", offset(of: trendDay.day)),
                    y: .value("傾向", trendDay.kilograms),
                    series: .value("線", "傾向")
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .accessibilityLabel("傾向 \(TimelineDayText.label(for: trendDay.day))")
                .accessibilityValue(WeightAmountText.kilograms(trendDay.kilograms))
            }
            if let last = chart.trend.last {
                // 線の端に今の傾向の値を添える
                PointMark(
                    x: .value("日", offset(of: last.day)), y: .value("傾向", last.kilograms)
                )
                .symbolSize(24)
                .foregroundStyle(Color.accentColor)
                .annotation(
                    position: .trailing, spacing: 4,
                    overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                ) {
                    Text(String(format: "%.1f", last.kilograms))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .accessibilityHidden(true)
            }
        }
        .chartXScale(domain: 0...max(totalDays, 1))
        .chartYScale(domain: yDomain)
        .chartXAxis {
            // 開始の日が今日（維持を立てた日）なら、終わりの目盛りを重ねない
            AxisMarks(values: totalDays > 0 ? [0, totalDays] : [0]) { value in
                AxisValueLabel(anchor: value.index == 0 ? .topLeading : .topTrailing) {
                    if let offset = value.as(Int.self) {
                        Text(axisLabel(offset))
                            .font(.caption2)
                            .monospacedDigit()
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let kilograms = value.as(Double.self) {
                        Text(String(format: "%.1f", kilograms))
                            .font(.caption2)
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(height: 160)
        .padding(.vertical, 8)
        // 目盛りの文字は xxxLarge で止める。高さを文字に合わせて伸ばすと、目盛りが重なって読めないため（WeightTrendChartView と同じ）。値は線の accessibilityValue でも読める
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private struct PathPoint {
        let offset: Int
        let kilograms: Double
    }

    private var totalDays: Int {
        chart.days.lowerBound.distance(to: chart.days.upperBound)
    }

    /// 減量・増量は開始の体重から期限の日の目標体重まで、維持は保つ体重の横の線
    private var pathPoints: [PathPoint] {
        let start =
            goal.direction.weightChange == nil
            ? goal.targetWeightKilograms : goal.startingWeightTrendKilograms
        return [
            PathPoint(offset: 0, kilograms: start),
            // 開始の日が今日でも、横軸の幅いっぱいに引く
            PathPoint(offset: max(totalDays, 1), kilograms: goal.targetWeightKilograms),
        ]
    }

    private func offset(of day: CalendarDay) -> Int {
        chart.days.lowerBound.distance(to: day)
    }

    /// 「10月1日」「12月24日」。維持の終わりは「今日」
    private func axisLabel(_ offset: Int) -> String {
        if offset > 0, goal.direction.weightChange == nil {
            return "今日"
        }
        let day = chart.days.lowerBound.advanced(by: offset)
        return "\(day.month)月\(day.day)日"
    }

    /// 線が収まる範囲。狭すぎると揺れが大きく見えるので 1 kg は取る
    private var yDomain: ClosedRange<Double> {
        let values = chart.trend.map(\.kilograms) + pathPoints.map(\.kilograms)
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        let middle = (low + high) / 2
        let half = max((high - low) / 2 + 0.3, 0.5)
        return (middle - half)...(middle + half)
    }
}
