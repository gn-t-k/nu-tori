import Foundation
import SwiftUI
import UIKit

/// タイムラインの下に固定する入力欄。左から「撮る」「写真」「体重」を寄せ、右は書く欄のために空けておく。
/// カメラを許可していない人が「撮る」を押したら、そのすぐ上に知らせを出す
struct TimelineComposer: View {
    let weightRecordedToday: Bool
    /// 体重のシートを開く前の、ヘルスケアの許可を求めているあいだ
    let preparingWeightEntry: Bool
    let showsCameraNotice: Bool
    let onCapture: () -> Void
    let onPickPhotos: () -> Void
    let onWeight: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if showsCameraNotice {
                cameraNotice
                    .padding(.horizontal)
            }
            ComposerButtonsLayout(spacing: 12) {
                Button(action: onCapture) {
                    circle(systemName: "camera.fill", filled: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("撮る")
                .accessibilityIdentifier("composer-capture")
                Button(action: onPickPhotos) {
                    circle(systemName: "photo.on.rectangle", filled: false)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("写真")
                .accessibilityIdentifier("composer-photos")
                weightButton
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    /// 文字を大きくしたとき、アイコンに合わせて丸も大きくする。3つの丸が画面の幅に収まるところで止める
    @ScaledMetric private var scaledButtonSize: CGFloat = 44
    private var buttonSize: CGFloat { min(scaledButtonSize, 88) }
    @Environment(\.openURL) private var openURL

    /// 今日の体重が未記録のあいだは、記録を促すため、文字の大きさによらず文字のカプセルに広げる。記録すると丸（体重計）に戻る。
    /// 大きな文字で「撮る」「写真」の横に入らないときは、ComposerButtonsLayout が下の行に全幅で置く
    private var weightButton: some View {
        Button(action: onWeight) {
            if weightRecordedToday {
                circle(systemName: "scalemass.fill", filled: false)
            } else {
                Text("体重を記録")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal)
                    // 1行に並べるときは文字の幅、下の行に送ったときは全幅にする
                    .frame(maxWidth: .infinity)
                    .frame(height: buttonSize)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(Color.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(preparingWeightEntry)
        .accessibilityLabel(weightRecordedToday ? "体重" : "体重を記録")
        .accessibilityIdentifier(
            weightRecordedToday ? "composer-weight" : "composer-weight-unrecorded")
    }

    /// ダイアログにせず、全幅の白いカードで知らせる。記録にも同期にも残さない
    private var cameraNotice: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text("カメラを許可していないため、撮れません。iPhone の設定で許可すると撮れます。")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("設定を開く") {
                if let settings = URL(string: UIApplication.openSettingsURLString) {
                    openURL(settings)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(
            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("camera-permission-notice")
    }

    /// 塗った丸は Primary の地に白、灰色の丸は Fill の地に Primary
    private func circle(systemName: String, filled: Bool) -> some View {
        Image(systemName: systemName)
            .frame(width: buttonSize, height: buttonSize)
            .background(filled ? Color.accentColor : Color(.tertiarySystemFill), in: Circle())
            .foregroundStyle(filled ? Color.white : Color.accentColor)
    }
}

/// 入力欄のボタンを左から1行に並べる。最後のボタン（体重）が1行に入らないときだけ、ほかのボタンの行の下に全幅で置く。
/// 入るかどうかは文字の大きさの段階でなく、ボタンの幅と入力欄の幅で決める
private struct ComposerButtonsLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        guard let width = proposal.width else {
            return CGSize(width: oneRowWidth(sizes), height: sizes.map(\.height).max() ?? 0)
        }
        guard let last = subviews.last, oneRowWidth(sizes) > width else {
            return CGSize(width: width, height: sizes.map(\.height).max() ?? 0)
        }
        let firstRowHeight = sizes.dropLast().map(\.height).max() ?? 0
        let lastHeight = last.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        return CGSize(width: width, height: firstRowHeight + spacing + lastHeight)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let wraps = oneRowWidth(sizes) > bounds.width
        let rowCount = wraps ? subviews.count - 1 : subviews.count
        let rowHeight = sizes.prefix(rowCount).map(\.height).max() ?? 0
        var x = bounds.minX
        for index in subviews.indices.prefix(rowCount) {
            subviews[index].place(
                at: CGPoint(x: x, y: bounds.minY + rowHeight / 2), anchor: .leading,
                proposal: ProposedViewSize(sizes[index]))
            x += sizes[index].width + spacing
        }
        if wraps, let last = subviews.last {
            last.place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + rowHeight + spacing),
                proposal: ProposedViewSize(width: bounds.width, height: nil))
        }
    }

    private func oneRowWidth(_ sizes: [CGSize]) -> CGFloat {
        sizes.map(\.width).reduce(0, +) + spacing * CGFloat(max(sizes.count - 1, 0))
    }
}
