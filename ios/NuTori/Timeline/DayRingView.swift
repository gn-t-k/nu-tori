import Charts
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
            if let arcs {
                Chart(sectors(arcs), id: \.self) { sector in
                    SectorMark(
                        angle: .value("一周のうちの長さ", sector.length),
                        innerRadius: .ratio(1 - 2 * lineWidth / diameter),
                        angularInset: lineWidth / 6
                    )
                    .foregroundStyle(sector.pfc?.color ?? Color.clear)
                }
                .chartLegend(.hidden)
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

    /// 塗る P・F・C と、一周に届かない残り（塗らない）
    private func sectors(_ arcs: DayRing.Arcs) -> [Sector] {
        let painted = PFC.allCases
            .map { Sector(pfc: $0, length: $0.length(in: arcs)) }
            .filter { $0.length > 0 }
        let rest = 1 - painted.reduce(0) { $0 + $1.length }
        // 一周に届いた日に、足し算の誤差で細い残りを作らない
        return rest > 1e-9 ? painted + [Sector(pfc: nil, length: rest)] : painted
    }

    private struct Sector: Hashable {
        /// 塗らない残りは nil
        let pfc: PFC?
        let length: Double
    }
}
