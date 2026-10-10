import SwiftUI

/// DESIGN.md の own-record-card。Surface に Primary を 10% 混ぜる。角はタイムラインのカード（12）、幅は画面の 72%
struct OwnRecordCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.accentColor.opacity(0.1))
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .containerRelativeFrame(.horizontal) { width, _ in
                let widthRatio: CGFloat = 0.72
                return width * widthRatio
            }
    }
}
