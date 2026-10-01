import Charts
import NuToriCore
import SwiftUI

/// 1日の丸。1本の輪を、P・F・C の kcal の割合で起点（上）から時計回りに塗り分け、色の間に細いすき間を空ける。
/// 割合が無い日は空の輪にする（DESIGN.md の Shapes の「1日の丸」）
struct DayRingView: View {
    let shares: PFCShares?
    let diameter: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color(.systemGray5), lineWidth: lineWidth)
            if let shares {
                Chart(PFC.allCases.filter { $0.share(of: shares) > 0 }, id: \.self) { pfc in
                    SectorMark(
                        angle: .value("kcal の割合", pfc.share(of: shares)),
                        innerRadius: .ratio(1 - 2 * lineWidth / diameter),
                        angularInset: lineWidth / 6
                    )
                    .foregroundStyle(pfc.color)
                }
                .chartLegend(.hidden)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}
