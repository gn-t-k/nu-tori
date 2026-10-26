import Charts
import NuToriCore
import SwiftUI

/// 週の振り返りの体重の段のグラフ。横軸は月〜日、目標の道筋は点線、傾向は Primary の線、記録は灰色の点（DESIGN.md の「グラフ」）。
/// 線が2本あるときは、線の端に「傾向」「目標」と添える。記録が4日未満の週は傾向の線を引かない
struct WeekRecapWeightChart: View {
    let recap: WeekRecap

    var body: some View {
        Chart {
            ForEach(goalPathPoints, id: \.offset) { point in
                LineMark(
                    x: .value("曜日", point.offset), y: .value("目標の道筋", point.kilograms),
                    series: .value("線", "目標の道筋")
                )
                .foregroundStyle(Color(.secondaryLabel))
                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                .accessibilityHidden(true)
            }
            ForEach(trendDays, id: \.day) { trendDay in
                LineMark(
                    x: .value("曜日", offset(of: trendDay.day)),
                    y: .value("傾向", trendDay.kilograms),
                    series: .value("線", "傾向")
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .accessibilityLabel("傾向 \(TimelineDayText.label(for: trendDay.day))")
                .accessibilityValue(WeightAmountText.kilograms(trendDay.kilograms))
            }
            ForEach(recordedDays, id: \.day) { day in
                PointMark(
                    x: .value("曜日", offset(of: day.day)),
                    y: .value("体重", day.kilograms)
                )
                .symbolSize(30)
                .foregroundStyle(Color(.secondaryLabel))
                .accessibilityLabel("体重 \(TimelineDayText.label(for: day.day))")
                .accessibilityValue(WeightAmountText.kilograms(day.kilograms))
            }
            if let trendEnd = trendDays.last, let goalEnd = goalPathPoints.last {
                // 系列が2本あるので、線の端に名前を添える（DESIGN.md の「グラフ」）。上にある線の名前を上に、下にある線の名前を下に置く
                let trendIsAbove = trendEnd.kilograms >= goalEnd.kilograms
                endLabelMark(
                    "傾向", offset: offset(of: trendEnd.day), kilograms: trendEnd.kilograms,
                    above: trendIsAbove)
                endLabelMark(
                    "目標", offset: goalEnd.offset, kilograms: goalEnd.kilograms,
                    above: !trendIsAbove)
            }
        }
        .chartXScale(domain: -0.5...6.5)
        .chartYScale(domain: yDomain)
        .chartXAxis { WeekdayAxis.marks(monday: recap.monday) }
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
        // 目盛りの文字は xxxLarge で止める。高さを文字に合わせて伸ばすと、曜日が重なって読めないため（WeightTrendChartView と同じ）。値は点の accessibilityValue でも読める
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func endLabelMark(_ name: String, offset: Int, kilograms: Double, above: Bool)
        -> some ChartContent
    {
        PointMark(x: .value("曜日", offset), y: .value("体重", kilograms))
            .symbolSize(0)
            .annotation(
                position: above ? .topTrailing : .bottomTrailing, spacing: 2,
                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
            ) {
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            .accessibilityHidden(true)
    }

    private struct PathPoint {
        let offset: Int
        let kilograms: Double
    }

    private struct RecordedDay {
        let day: CalendarDay
        let kilograms: Double
    }

    private var goalPathPoints: [PathPoint] {
        guard let first = recap.days.first?.day, let last = recap.days.last?.day else { return [] }
        return [
            PathPoint(offset: offset(of: first), kilograms: recap.weight.goalPath.firstKilograms),
            PathPoint(offset: offset(of: last), kilograms: recap.weight.goalPath.lastKilograms),
        ]
    }

    private var trendDays: [WeightTrend.Day] {
        switch recap.weight.trendLine {
        case .drawn(let days): days
        case .tooFewRecordedDays: []
        }
    }

    private var recordedDays: [RecordedDay] {
        recap.days.compactMap { day in
            day.weightKilograms.map { RecordedDay(day: day.day, kilograms: $0) }
        }
    }

    private func offset(of day: CalendarDay) -> Int {
        recap.monday.distance(to: day)
    }

    /// 点と線が収まる範囲。狭すぎると揺れが大きく見えるので 1 kg は取る
    private var yDomain: ClosedRange<Double> {
        let values =
            recordedDays.map(\.kilograms) + trendDays.map(\.kilograms)
            + goalPathPoints.map(\.kilograms)
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        let middle = (low + high) / 2
        let half = max((high - low) / 2 + 0.2, 0.5)
        return (middle - half)...(middle + half)
    }
}
