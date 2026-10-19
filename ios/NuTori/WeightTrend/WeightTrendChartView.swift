import Charts
import NuToriCore
import SwiftUI

/// 体重の画面の、最近4週の傾向のグラフ。点は測った体重（日の代表値）、線はサーバーから届いた傾向。
/// 目標があれば目標体重の点線（縦軸に入らなければ端の矢印、維持は保つ幅を薄く塗る）。
/// 色は DESIGN.md の「グラフ」: 線は Primary、点は文字の灰色、使い始める前の点はさらに薄く、目標は点線、グリッドは薄く
struct WeightTrendChartView: View {
    let chart: WeightTrendChart

    var body: some View {
        Chart {
            targetMarks
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
        .chartOverlay { targetBeyondRange(proxy: $0) }
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
        chart.trendLine.days
    }

    /// 目標体重の点線と、維持の保つ幅。縦軸に入らない目標体重は `targetBeyondRange` が端に書く
    @ChartContentBuilder private var targetMarks: some ChartContent {
        if case .band(let kilograms, let halfWidth) = chart.target {
            RectangleMark(
                xStart: .value("日", 0), xEnd: .value("日", lastOffset),
                yStart: .value("保つ幅", kilograms - halfWidth),
                yEnd: .value("保つ幅", kilograms + halfWidth)
            )
            .foregroundStyle(Color(.tertiaryLabel).opacity(0.18))
            .accessibilityHidden(true)
        }
        if let kilograms = ruledTargetKilograms {
            targetRule(kilograms)
        }
    }

    /// 点線を引く目標体重。縦軸に入らなければ nil
    private var ruledTargetKilograms: Double? {
        switch chart.target {
        case .line(let kilograms), .band(let kilograms, _): kilograms
        case .beyondRange, nil: nil
        }
    }

    private func targetRule(_ kilograms: Double) -> some ChartContent {
        RuleMark(y: .value("目標", kilograms))
            .foregroundStyle(Color(.secondaryLabel))
            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            .annotation(
                position: .top, alignment: .trailing, spacing: 2,
                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
            ) {
                Text(chart.target?.label ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(chart.target?.label ?? "")
    }

    /// 目標体重が縦軸に入らないとき、点線の代わりに上か下の端に「↓ 目標 70.0 kg」と書く
    private func targetBeyondRange(proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            if case .beyondRange(_, let isAbove) = chart.target, let plotFrame = proxy.plotFrame {
                let plot = geometry[plotFrame]
                Text(chart.target?.label ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .frame(
                        width: plot.width, height: plot.height,
                        alignment: isAbove ? .topTrailing : .bottomTrailing
                    )
                    .position(x: plot.midX, y: plot.midY)
            }
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

    /// 縦軸は、点と線と保つ幅が収まる範囲（`WeightTrendChart.kilogramsRange`）
    private var yDomain: ClosedRange<Double> {
        chart.kilogramsRange
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
