import NuToriCore
import SwiftUI

/// タイムラインのナビゲーションバーの左に置く、目標の画面への入口（仕様の `glink` F）。
/// 灰色のカプセルに、開始の体重から目標体重までの進み具合の輪（20 pt、Primary の1色、中に旗は入れない）と1行
struct GoalLinkCapsuleButton: View {
    let capsule: GoalLinkCapsule
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 4) {
                ring
                Text(capsule.text)
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .foregroundStyle(Color.accentColor)
            .padding(.leading, 6)
            .padding(.trailing, 10)
            .frame(minHeight: 30)
            // DESIGN.md の Fill（tertiarySystemFill）。灰色のカプセル
            .background(Color(.tertiarySystemFill), in: Capsule())
            .contentShape(Capsule())
            // ナビゲーションバーの左は狭く割り当てられるので、1行を縮めずに出す
            .fixedSize()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("目標、\(capsule.text)")
        .accessibilityValue("進み具合 \(capsule.progressPercent)%")
        .accessibilityHint("目標の画面を開きます")
        .accessibilityIdentifier("goal-link")
    }

    @ScaledMetric(relativeTo: .footnote) private var diameter: CGFloat = 20

    private var ring: some View {
        let lineWidth = diameter * 0.175
        return ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: capsule.progress)
                .stroke(
                    Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}
