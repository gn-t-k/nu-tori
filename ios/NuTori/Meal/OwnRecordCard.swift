import SwiftUI

/// DESIGN.md の own-record-card。Surface に Primary を 22% 混ぜる。角はタイムラインのカード（12）、幅は画面の 72%
struct OwnRecordCard: ViewModifier {
    /// Surface に混ぜる Primary の濃さ。体重の行と、吹き出しにつないだ食事の行もこの地にそろえる
    static let tintOpacity = 0.22

    func body(content: Content) -> some View {
        content
            .background(Color.accentColor.opacity(Self.tintOpacity))
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .containerRelativeFrame(.horizontal) { width, _ in
                let widthRatio: CGFloat = 0.72
                return width * widthRatio
            }
    }
}
