// PROTOTYPE: 捨てる。比較の画像を /tmp に書き出すだけ
import SwiftUI
import Testing

@testable import NuTori

@MainActor
@Suite("PROTOTYPE 体重のグラフの比較")
struct WeightTrendChartPrototypeRender {
    @Test func render() throws {
        let comparisons: [(file: String, view: PrototypeComparison)] = [
            (
                "q1-text-and-grid",
                PrototypeComparison(
                    title: "問い1: 文字の大きさと縦のグリッド",
                    variants: [
                        ("A 今\nxxxLarge で止める\n縦のグリッド無し", PrototypeChartOptions()),
                        ("B Dynamic Type に従う\n高さ・余白を\n@ScaledMetric で伸ばす", PrototypeChartOptions(text: .scaled)),
                        ("C 今＋縦のグリッド", PrototypeChartOptions(verticalGrid: true)),
                    ])
            ),
            (
                "q2-divider",
                PrototypeComparison(
                    title: "問い2: 使い始めの点線の位置（使い始め 9/15）",
                    variants: [
                        ("A 今\n使い始めた日の上", PrototypeChartOptions()),
                        ("B 試作\n前の日とのあいだ\n（-0.5 日）", PrototypeChartOptions(dividerHalfDayBefore: true)),
                    ])
            ),
        ]
        for comparison in comparisons {
            let renderer = ImageRenderer(content: comparison.view)
            renderer.scale = 2
            let data = try #require(renderer.uiImage?.pngData())
            try data.write(to: URL(fileURLWithPath: "/tmp/nu-tori-prototype-\(comparison.file).png"))
        }
    }
}
