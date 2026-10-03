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
                    .annotation(
                        position: .trailing, alignment: .top, spacing: 4,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
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
        // Charts の AxisValueLabel は目盛りの右にずれ、今日のラベルが消えるので、横軸のラベルは自前で描く。縦のグリッドも引かない。今日から1週ずつの目盛りの線が、使い始めの点線と並んで紛れるため
        .chartXAxis(.hidden)
        .chartOverlay { xAxisLabels(proxy: $0) }
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
        // 下は横軸のラベルの行、左右は両端のラベルがはみ出さない余白。DESIGN.md の Layout は自前の数値を持たないとするが、Charts の描く範囲を空ける標準の余白が無いので、文字を xxxLarge で止めたときに収まる値を持つ
        .chartPlotStyle { plot in
            plot.padding(.horizontal, Self.edgeInset).padding(.bottom, Self.xAxisLabelRowHeight)
        }
        .frame(height: 200)
        // DESIGN.md の Typography は Dynamic Type に従うとするが、目盛りと注釈の文字は xxxLarge で止める。高さと余白を文字に合わせて伸ばすと、AX 5 で画面の2倍近くの高さになり、横軸の日付が重なって読めないため。値は点の accessibilityValue でも読める
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private static let edgeInset: CGFloat = 16
    private static let xAxisLabelRowHeight: CGFloat = 24

    /// 目盛り（今日から1週ずつさかのぼった日）の真下に、日付を描く。VoiceOver には点の読み上げがあるので隠す
    private func xAxisLabels(proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            if let plotFrame = proxy.plotFrame {
                let plot = geometry[plotFrame]
                ForEach(xTicks, id: \.self) { tick in
                    if let x = proxy.position(forX: tick) {
                        Text(monthDay(chart.days.lowerBound.advanced(by: tick)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .position(x: plot.minX + x, y: plot.maxY + Self.xAxisLabelRowHeight / 2)
                    }
                }
            }
        }
        .accessibilityHidden(true)
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
