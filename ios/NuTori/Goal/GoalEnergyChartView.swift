import Charts
import NuToriCore
import SwiftUI

/// 推定消費カロリーの線と1日の目安の階段を、1つの kcal のグラフに重ねる（仕様の `gchart` B）。2本の間を薄く塗り、見送った週に「見送り」の印。
/// 見直した点が3つたまるまでは、グラフの代わりに今の値の数字を出す。グラフの週を押すと、その週の値をグラフの上に出す
struct GoalEnergyChartView: View {
    let chart: GoalOverview.EnergyChart

    var body: some View {
        switch chart {
        case .drawn(let graph):
            GoalEnergyGraph(graph: graph)
        case .figures(let figures):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(figures, id: \.self) { figure in
                    Text(figure)
                        .monospacedDigit()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("goal-energy-figures")
        }
    }
}

private struct GoalEnergyGraph: View {
    let graph: GoalOverview.EnergyChart.Graph

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            selectionLine
            Chart {
                ForEach(graph.points, id: \.day) { point in
                    AreaMark(
                        x: .value("日", offset(of: point.day)),
                        yStart: .value("1日の目安", point.dailyGuideKilocalories),
                        yEnd: .value("推定消費カロリー", point.expenditureKilocalories)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.1))
                    .accessibilityHidden(true)
                }
                ForEach(graph.points, id: \.day) { point in
                    LineMark(
                        x: .value("日", offset(of: point.day)),
                        y: .value("kcal", point.expenditureKilocalories),
                        series: .value("線", "推定消費カロリー")
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .symbol {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 5, height: 5)
                    }
                    .accessibilityLabel("推定消費カロリー \(TimelineDayText.label(for: point.day))")
                    .accessibilityValue(NutritionText.kilocalories(point.expenditureKilocalories))
                }
                ForEach(stepPoints, id: \.offset) { point in
                    LineMark(
                        x: .value("日", point.offset),
                        y: .value("kcal", point.kilocalories),
                        series: .value("線", "1日の目安")
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                    .accessibilityHidden(true)
                }
                ForEach(graph.points, id: \.day) { point in
                    // 階段は読み上げで点ごとに読む（線は accessibilityHidden）
                    PointMark(
                        x: .value("日", offset(of: point.day)),
                        y: .value("kcal", point.dailyGuideKilocalories)
                    )
                    .symbolSize(0)
                    .accessibilityLabel("1日の目安 \(TimelineDayText.label(for: point.day))から")
                    .accessibilityValue(NutritionText.kilocalories(point.dailyGuideKilocalories))
                }
                ForEach(graph.deferredDays, id: \.self) { day in
                    RuleMark(x: .value("日", offset(of: day)))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                        .annotation(position: .bottom, alignment: .center) {
                            Text("見送り")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("\(TimelineDayText.label(for: day))の週は、1日の目安をそのままにしました")
                }
                if let last = graph.points.last {
                    // 系列が2本あるので、線の端に名前を添える（DESIGN.md の「グラフ」）
                    PointMark(
                        x: .value("日", offset(of: last.day)),
                        y: .value("kcal", last.expenditureKilocalories)
                    )
                    .symbolSize(0)
                    .annotation(
                        position: .topTrailing, spacing: 2,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                    ) {
                        endLabel("推定 \(NutritionText.kilocalories(last.expenditureKilocalories))")
                    }
                    .accessibilityHidden(true)
                    PointMark(
                        x: .value("日", offset(of: last.day)),
                        y: .value("kcal", last.dailyGuideKilocalories)
                    )
                    .symbolSize(0)
                    .annotation(
                        position: .bottomTrailing, spacing: 2,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                    ) {
                        endLabel("目安 \(NutritionText.kilocalories(last.dailyGuideKilocalories))")
                    }
                    .accessibilityHidden(true)
                }
                if let selected = selectedPoint {
                    RuleMark(x: .value("日", offset(of: selected.day)))
                        .foregroundStyle(Color(.separator))
                        .accessibilityHidden(true)
                }
            }
            .chartXScale(domain: 0...max(totalDays, 1))
            .chartYScale(domain: yDomain)
            .chartXSelection(value: $selectedOffset)
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
                        if let kilocalories = value.as(Int.self) {
                            Text(NutritionText.kilocalories(kilocalories))
                                .font(.caption2)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .frame(height: 180)
            .padding(.vertical, 8)
            // 目盛りの文字は xxxLarge で止める（体重のグラフと同じ）。値は点の accessibilityValue でも読める
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }

    @State private var selectedOffset: Int?

    private struct StepPoint {
        let offset: Int
        let kilocalories: Int
    }

    /// 押した週の値。押していなければ出さない（線の端の名前に、いちばん新しい値がある）
    @ViewBuilder private var selectionLine: some View {
        if let selected = selectedPoint {
            Text(
                "\(TimelineDayText.label(for: selected.day))から　推定 \(NutritionText.kilocalories(selected.expenditureKilocalories))・目安 \(NutritionText.kilocalories(selected.dailyGuideKilocalories))"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 押した日に当たっていた点（その日以前で最も新しい当てる始まりの日）
    private var selectedPoint: GoalOverview.EnergyChart.Point? {
        guard let selectedOffset else { return nil }
        return graph.points.last { offset(of: $0.day) <= selectedOffset } ?? graph.points.first
    }

    private func endLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .fixedSize()
    }

    private var totalDays: Int {
        graph.days.lowerBound.distance(to: graph.days.upperBound)
    }

    /// 階段は、いちばん新しい1日の目安を横軸の終わりまで延ばす
    private var stepPoints: [StepPoint] {
        let points = graph.points.map {
            StepPoint(offset: offset(of: $0.day), kilocalories: $0.dailyGuideKilocalories)
        }
        guard let last = points.last, last.offset < totalDays else { return points }
        return points + [StepPoint(offset: totalDays, kilocalories: last.kilocalories)]
    }

    private func offset(of day: CalendarDay) -> Int {
        graph.days.lowerBound.distance(to: day)
    }

    /// 「10月1日」「12月24日」
    private func axisLabel(_ offset: Int) -> String {
        let day = graph.days.lowerBound.advanced(by: offset)
        return "\(day.month)月\(day.day)日"
    }

    /// 2本が収まる範囲。上下に 150 kcal ずつ空ける
    private var yDomain: ClosedRange<Int> {
        let values = graph.points.flatMap {
            [$0.expenditureKilocalories, $0.dailyGuideKilocalories]
        }
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        return (low - 150)...(high + 150)
    }
}
