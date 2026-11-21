import NuToriCore
import SwiftUI

/// 1日の丸。1本の輪を、P・F・C の長さで起点（上）から時計回りに塗り分け、色の間に細いすき間を空ける。
/// 1日の目安と比べる日は一周を目安にして食べた分だけ進み、目安を超えた日は輪の起点に文字の色の点を付ける。
/// 比べない日は P・F・C の割合で一周する。塗る長さが無い日は空の輪にする（DESIGN.md の「1日の丸」）
struct DayRingView: View {
    let arcs: DayRing.Arcs?
    let exceedsDailyGuide: Bool
    let diameter: CGFloat
    let lineWidth: CGFloat
    /// 丸を置いた地の色。超えた印のふちを地の色にして、輪の色と分ける
    let background: Color

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color(.systemGray5), lineWidth: lineWidth)
            // 塗りの長さが変わったときに伸び縮みさせるため、Swift Charts でなく、長さを動かせる形で描く。
            // Charts の扇を動かすと、Charts の中でアプリが落ちた（#325）
            ForEach(PFC.allCases, id: \.self) { pfc in
                let arcSpan = span(of: pfc)
                RingArc(
                    start: arcSpan.start, end: arcSpan.end, lineWidth: lineWidth,
                    inset: arcSpan.isWhole ? 0 : lineWidth / 6
                )
                .fill(pfc.color)
            }
        }
        .frame(width: diameter, height: diameter)
        .overlay(alignment: .top) {
            if exceedsDailyGuide {
                Circle()
                    .fill(Color.primary)
                    .overlay(Circle().stroke(background, lineWidth: 1.5))
                    .frame(width: markDiameter, height: markDiameter)
                    // 点の中心を輪の線の真ん中に置く
                    .offset(y: lineWidth / 2 - markDiameter / 2)
            }
        }
        .accessibilityHidden(true)
    }

    /// 超えた印の大きさ。線の太さに合わせる（コンポーネントの見本の `_ring.js` と同じ比）
    private var markDiameter: CGFloat {
        2 * max(2, lineWidth * 0.6)
    }

    /// 起点（上）から時計回りに P・F・C の順で塗る、この栄養の始まりと終わり（一周を 1 とする）。
    /// 塗る長さが無い日は長さ 0 にして、その日の最初の食事でも 0 から伸びるようにする
    private func span(of pfc: PFC) -> (start: Double, end: Double, isWhole: Bool) {
        guard let arcs else { return (0, 0, false) }
        let before = PFC.allCases.prefix { $0 != pfc }.reduce(0) { $0 + $1.length(in: arcs) }
        let length = pfc.length(in: arcs)
        // 1つの栄養だけで一周に届いた日は、すき間を空けずに輪を閉じる
        return (before, before + length, length >= 1 - 1e-9)
    }
}

/// 1日の丸の1色ぶんの弧。始まりと終わりを動かせるので、塗りの長さが変わると伸び縮みする。
/// 色の間のすき間は、両端を `inset`（線の真ん中での長さ）ずつ削って作る（Swift Charts の `angularInset` と同じ見た目）
private struct RingArc: Shape {
    var start: Double
    var end: Double
    let lineWidth: CGFloat
    let inset: CGFloat

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(start, end) }
        set {
            start = newValue.first
            end = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2 - lineWidth / 2
        guard radius > 0 else { return Path() }
        let insetTurns = Double(inset / (2 * .pi * radius))
        let from = start + insetTurns
        let to = end - insetTurns
        guard to > from else { return Path() }
        var arc = Path()
        arc.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY), radius: radius,
            startAngle: .degrees(from * 360 - 90), endAngle: .degrees(to * 360 - 90),
            clockwise: false)
        return arc.strokedPath(StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
    }
}
