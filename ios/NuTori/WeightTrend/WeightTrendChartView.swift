import Charts
import NuToriCore
import SwiftUI

/// 体重の画面の、最近4週の傾向のグラフ。点は測った体重（日の代表値）、線はサーバーから届いた傾向。
/// 色は DESIGN.md の「グラフ」: 線は Primary、点は文字の灰色、使い始める前の点はさらに薄く、グリッドは薄く
struct WeightTrendChartView: View {
    let chart: WeightTrendChart

    var body: some View {
        Chart {
            if let divider = chart.firstDayDivider {
                RuleMark(x: .value("日", offset(of: divider)))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .trailing, alignment: .top, spacing: 4) {
                        Text("使い始め")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("使い始め")
                    .accessibilityValue(TimelineDayText.label(for: divider))
            }
            ForEach(lineDays, id: \.day) { trendDay in
                LineMark(
                    x: .value("日", offset(of: trendDay.day)),
                    y: .value("傾向", trendDay.kilograms)
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .accessibilityLabel("傾向 \(TimelineDayText.label(for: trendDay.day))")
                .accessibilityValue(WeightAmountText.kilograms(trendDay.kilograms))
            }
            // 送り待ちの点も形で見分けない
            ForEach(chart.points, id: \.day) { point in
                PointMark(
                    x: .value("日", offset(of: point.day)),
                    y: .value("体重", point.kilograms)
                )
                .symbolSize(30)
                .foregroundStyle(
                    point.isBeforeFirstDay ? Color(.tertiaryLabel) : Color(.secondaryLabel)
                )
                .accessibilityLabel("体重 \(TimelineDayText.label(for: point.day))")
                .accessibilityValue(WeightAmountText.kilograms(point.kilograms))
            }
        }
        .chartXScale(domain: 0...lastOffset)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: xTicks) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let offset = value.as(Int.self) {
                        Text(monthDay(chart.days.lowerBound.advanced(by: offset)))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yTicks) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let kilograms = value.as(Double.self) {
                        Text("\(Int(kilograms.rounded()))")
                            .font(.caption2)
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(height: 200)
    }

    private var lineDays: [WeightTrend.Day] {
        switch chart.trendLine {
        case .drawn(let days): days
        case .tooFewRecordedDays: []
        }
    }

    /// 横軸は、4週の左端（27 日前）からの日数で描く
    private func offset(of day: CalendarDay) -> Int {
        chart.days.lowerBound.distance(to: day)
    }

    private var lastOffset: Int {
        offset(of: chart.days.upperBound)
    }

    /// 今日から1週ずつさかのぼった日に目盛りを付ける
    private var xTicks: [Int] {
        Array(stride(from: lastOffset, through: 0, by: -7).reversed())
    }

    /// 4週の中の点と線が収まる、整数の kg で区切った範囲。狭すぎると揺れが大きく見えるので 2 kg は取る
    private var yDomain: ClosedRange<Double> {
        let values = chart.points.map(\.kilograms) + lineDays.map(\.kilograms)
        guard let minimum = values.min(), let maximum = values.max() else {
            return 0...2
        }
        let lower = (minimum - 0.3).rounded(.down)
        let upper = max((maximum + 0.3).rounded(.up), lower + 2)
        return lower...upper
    }

    /// 整数の kg に目盛りを付け、範囲が広いときは 2 kg ごとにする
    private var yTicks: [Double] {
        let step: Double = yDomain.upperBound - yDomain.lowerBound > 4 ? 2 : 1
        return Array(stride(from: yDomain.lowerBound, through: yDomain.upperBound, by: step))
    }

    private func monthDay(_ day: CalendarDay) -> String {
        "\(day.month)/\(day.day)"
    }
}
