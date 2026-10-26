import Charts
import NuToriCore
import SwiftUI

/// 今の1日の目安のカードの、PFC より下（#744 の解決コメント）。推定消費カロリーと1日の目安を 0 kcal からの同じ目盛りの2本の棒で並べ、差を斜線で見せる。
/// 見直した点が3つたまったら、棒の下に、推定消費カロリーの線と1日の目安の階段を重ねたグラフ（仕様の `gchart` B）を描く
struct GoalEnergyChartView: View {
    let chart: GoalOverview.EnergyChart

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GoalEnergyBars(bars: chart.bars)
            if let graph = chart.graph {
                Divider()
                    .padding(.vertical, 4)
                GoalEnergyGraph(graph: graph)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("goal-energy-chart")
    }
}

/// 推定消費カロリーは灰色、1日の目安は Primary の棒。差（減量は減らす分、増量は足す分）は、短いほうの棒の先に斜線で置く。
/// DESIGN.md の「グラフ」は Swift Charts で描くが、この棒は軸も目盛りも持たず、名前と数字を棒の上の行に書くので、自前で描く
private struct GoalEnergyBars: View {
    let bars: GoalOverview.EnergyChart.Bars

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 「推定」「目安」だけでは何のことかわからないので、名前は用語のまま棒の上に書く
            label("推定消費カロリー", kilocalories: bars.expenditureKilocalories)
            bar(kilocalories: bars.expenditureKilocalories, color: Color(.tertiaryLabel))
                .padding(.bottom, 6)
            label("1日の目安", kilocalories: bars.dailyGuideKilocalories)
            bar(kilocalories: bars.dailyGuideKilocalories, color: .accentColor)
            if let gap = bars.gap {
                // DESIGN.md の Primary は押せるものに使うが、差の文は押せない。それでも Primary で書き、同じ色の斜線がこの差だと結びつける（#744 の試作の案 I）
                Text(gap)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("goal-energy-bars")
    }

    /// 「推定消費カロリー」「2,160 kcal」。大きな文字で横に収まらなければ、数字を名前の下に置く
    private func label(_ name: String, kilocalories: Int) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(name)
                Spacer(minLength: 8)
                Text(NutritionText.kilocalories(kilocalories))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                Text(NutritionText.kilocalories(kilocalories))
            }
        }
    }

    /// 0 kcal から `kilocalories` までを塗り、長いほうの棒の先まで届かなければ、残りを斜線にする
    private func bar(kilocalories: Int, color: Color) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let filled = width * fraction(kilocalories)
            ZStack(alignment: .leading) {
                if filled < width {
                    GoalEnergyHatch()
                        .frame(width: width - filled)
                        .offset(x: filled)
                }
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: filled)
            }
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }

    private func fraction(_ kilocalories: Int) -> CGFloat {
        let longest = max(bars.expenditureKilocalories, bars.dailyGuideKilocalories)
        guard longest > 0 else { return 0 }
        return CGFloat(kilocalories) / CGFloat(longest)
    }
}

/// 差の斜線。Primary の細い枠に、薄い Primary の斜めの線
private struct GoalEnergyHatch: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 3)
        DiagonalStripes(spacing: 6)
            .stroke(Color.accentColor.opacity(0.35), lineWidth: 2)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.accentColor, lineWidth: 1.2))
    }
}

/// 左下から右上へ、`spacing` おきに引く斜めの線
nonisolated private struct DiagonalStripes: Shape {
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }
        return path
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
                    // DESIGN.md の「グラフ」は線の端に名前を添えるが、端には数字だけを置き、名前はグラフの下の凡例に用語のまま書く。
                    // 「推定」「目安」と縮めると何のことかわからず、用語のままでは端に収まらないため（#744 の解決コメント）
                    PointMark(
                        x: .value("日", offset(of: last.day)),
                        y: .value("kcal", last.expenditureKilocalories)
                    )
                    .symbolSize(0)
                    .annotation(
                        position: .topTrailing, spacing: 2,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                    ) {
                        endLabel(NutritionText.kilocalories(last.expenditureKilocalories))
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
                        endLabel(NutritionText.kilocalories(last.dailyGuideKilocalories))
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
            legend
        }
    }

    @State private var selectedOffset: Int?

    /// 「● 推定消費カロリー ┄ 1日の目安」。線の端には数字だけを置くので、名前はここに書く
    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { legendItems }
            VStack(alignment: .leading, spacing: 4) { legendItems }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var legendItems: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
            Text("推定消費カロリー")
        }
        HStack(spacing: 6) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 1))
                path.addLine(to: CGPoint(x: 14, y: 1))
            }
            .stroke(Color(.secondaryLabel), style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
            .frame(width: 14, height: 2)
            Text("1日の目安")
        }
    }

    private struct StepPoint {
        let offset: Int
        let kilocalories: Int
    }

    /// 押した週の値。押していなければ出さない（線の端の名前に、いちばん新しい値がある）
    @ViewBuilder private var selectionLine: some View {
        if let selected = selectedPoint {
            Text(
                "\(TimelineDayText.label(for: selected.day))から　推定消費カロリー \(NutritionText.kilocalories(selected.expenditureKilocalories))・1日の目安 \(NutritionText.kilocalories(selected.dailyGuideKilocalories))"
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
