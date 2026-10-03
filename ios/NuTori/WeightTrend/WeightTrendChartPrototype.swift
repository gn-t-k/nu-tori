#if DEBUG
    // PROTOTYPE: 捨てる。main に入れない（ブランチ prototype/weight-trend-chart-variants）
    // 問い1: グラフの文字を xxxLarge で止めるか、Dynamic Type に従わせて @ScaledMetric で伸ばすか。縦のグリッドは要るか
    // 問い2: 使い始めの区切りの点線を、使い始めた日の上に引くか、前の日とのあいだ（-0.5 日）に引くか
    import Charts
    import NuToriCore
    import SwiftUI

    struct PrototypeChartOptions {
        enum TextSize { case capped, scaled }
        var text: TextSize = .capped
        var verticalGrid = false
        var dividerHalfDayBefore = false
    }

    private struct PrototypePoint: Hashable {
        let offset: Int
        let kilograms: Double
        let isBeforeFirstDay: Bool
    }

    /// 見本: 4週の左端が 9/1、今日が 9/28。使い始めは 9/15、その前はヘルスケアから取り込んだ点
    private enum PrototypeSample {
        static let start = CalendarDay(year: 2026, month: 9, day: 1)
        static let lastOffset = 27
        static let firstDayOffset = 14
        static let points: [PrototypePoint] = [0, 2, 3, 6, 8, 10, 13, 14, 15, 16, 17, 18, 20, 21, 22, 24, 25, 26, 27]
            .map { offset in
                let wobble = [0.3, -0.2, 0.1, -0.3, 0.2, 0.0, -0.1][offset % 7]
                return PrototypePoint(
                    offset: offset, kilograms: 71.2 - 0.06 * Double(offset) + wobble,
                    isBeforeFirstDay: offset < firstDayOffset)
            }
        static let line: [(offset: Int, kilograms: Double)] = (firstDayOffset...lastOffset).map {
            ($0, 71.2 - 0.06 * Double($0))
        }
    }

    struct WeightTrendChartPrototype: View {
        let options: PrototypeChartOptions

        @ScaledMetric(relativeTo: .caption2) private var scaledHeight: CGFloat = 200
        @ScaledMetric(relativeTo: .caption2) private var scaledEdgeInset: CGFloat = 16
        @ScaledMetric(relativeTo: .caption2) private var scaledLabelRow: CGFloat = 24

        private var height: CGFloat { options.text == .scaled ? scaledHeight : 200 }
        private var edgeInset: CGFloat { options.text == .scaled ? scaledEdgeInset : 16 }
        private var labelRow: CGFloat { options.text == .scaled ? scaledLabelRow : 24 }

        var body: some View {
            let chart = Chart {
                RuleMark(x: .value("日", dividerX))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(
                        position: .trailing, alignment: .top, spacing: 4,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        Text("使い始め").font(.caption2).foregroundStyle(.secondary)
                    }
                ForEach(PrototypeSample.line, id: \.offset) { day in
                    LineMark(x: .value("日", Double(day.offset)), y: .value("傾向", day.kilograms))
                        .foregroundStyle(Color.accentColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
                ForEach(PrototypeSample.points, id: \.self) { point in
                    PointMark(x: .value("日", Double(point.offset)), y: .value("体重", point.kilograms))
                        .symbolSize(30)
                        .foregroundStyle(
                            point.isBeforeFirstDay ? Color(.tertiaryLabel) : Color(.secondaryLabel))
                }
            }
            .chartXScale(domain: 0...Double(PrototypeSample.lastOffset))
            .chartYScale(domain: 68.0...72.0)
            .chartXAxis {
                AxisMarks(values: xTicks) { _ in
                    if options.verticalGrid { AxisGridLine() }
                }
            }
            .chartOverlay { xAxisLabels(proxy: $0) }
            .chartYAxis {
                AxisMarks(position: .leading, values: [68.0, 69.0, 70.0, 71.0, 72.0]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let kilograms = value.as(Double.self) {
                            Text("\(Int(kilograms))").font(.caption2).monospacedDigit()
                        }
                    }
                }
            }
            .chartPlotStyle { $0.padding(.horizontal, edgeInset).padding(.bottom, labelRow) }
            .frame(height: height)

            switch options.text {
            case .capped: chart.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            case .scaled: chart
            }
        }

        private var dividerX: Double {
            Double(PrototypeSample.firstDayOffset) - (options.dividerHalfDayBefore ? 0.5 : 0)
        }

        private var xTicks: [Double] {
            stride(from: PrototypeSample.lastOffset, through: 0, by: -7).reversed().map(Double.init)
        }

        private func xAxisLabels(proxy: ChartProxy) -> some View {
            GeometryReader { geometry in
                if let plotFrame = proxy.plotFrame {
                    let plot = geometry[plotFrame]
                    ForEach(xTicks, id: \.self) { tick in
                        if let x = proxy.position(forX: tick) {
                            let day = PrototypeSample.start.advanced(by: Int(tick))
                            Text("\(day.month)/\(day.day)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .position(x: plot.minX + x, y: plot.maxY + labelRow / 2)
                        }
                    }
                }
            }
        }
    }

    /// 体重の画面の節に似せた1枚
    private struct PrototypeCell: View {
        let options: PrototypeChartOptions
        let scheme: ColorScheme
        let size: DynamicTypeSize

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("最近4週").font(.headline)
                WeightTrendChartPrototype(options: options)
                Text("1週間で −0.4 kg").font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
            .padding(16)
            .frame(width: 402)
            .background(Color(.systemGroupedBackground))
            .environment(\.colorScheme, scheme)
            .environment(\.dynamicTypeSize, size)
        }
    }

    struct PrototypeComparison: View {
        let title: String
        let variants: [(name: String, options: PrototypeChartOptions)]

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(title).font(.title2.bold())
                HStack(spacing: 16) {
                    Spacer().frame(width: 160)
                    ForEach(["ライト", "ダーク", "AX 5"], id: \.self) {
                        Text($0).font(.headline).frame(width: 402)
                    }
                }
                ForEach(variants, id: \.name) { variant in
                    HStack(alignment: .top, spacing: 16) {
                        Text(variant.name).font(.headline).frame(width: 160, alignment: .leading)
                        PrototypeCell(options: variant.options, scheme: .light, size: .large)
                        PrototypeCell(options: variant.options, scheme: .dark, size: .large)
                        PrototypeCell(options: variant.options, scheme: .light, size: .accessibility5)
                    }
                }
            }
            .padding(24)
            .background(Color.white)
            .environment(\.colorScheme, .light)
            .dynamicTypeSize(.large)
        }
    }

    #Preview("問い1 文字と縦のグリッド", traits: .sizeThatFitsLayout) {
        PrototypeComparison(
            title: "問い1: 文字の大きさと縦のグリッド",
            variants: [
                ("A 今\nxxxLarge で止める\n縦のグリッド無し", PrototypeChartOptions()),
                ("B Dynamic Type に従う\n高さ・余白を\n@ScaledMetric で伸ばす", PrototypeChartOptions(text: .scaled)),
                ("C 今＋縦のグリッド", PrototypeChartOptions(verticalGrid: true)),
            ])
    }

    #Preview("問い2 点線の位置", traits: .sizeThatFitsLayout) {
        PrototypeComparison(
            title: "問い2: 使い始めの点線の位置（使い始め 9/15）",
            variants: [
                ("A 今\n使い始めた日の上", PrototypeChartOptions()),
                ("B 試作\n前の日とのあいだ\n（-0.5 日）", PrototypeChartOptions(dividerHalfDayBefore: true)),
            ])
    }
#endif
