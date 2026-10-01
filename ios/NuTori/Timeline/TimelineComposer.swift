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
            HStack(spacing: 12) {
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
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    /// 文字を大きくしたとき、アイコンに合わせて丸も大きくする
    @ScaledMetric private var buttonSize: CGFloat = 44
    @Environment(\.openURL) private var openURL

    /// 今日の体重が未記録のあいだは、文字のカプセルに広げる。記録すると丸（体重計）に戻る
    private var weightButton: some View {
        Button(action: onWeight) {
            if weightRecordedToday {
                circle(systemName: "scalemass.fill", filled: false)
            } else {
                Text("体重を記録")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal)
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
