import SwiftUI

/// DESIGN.md の own-record-time。自分の記録（体重・食事・送った文章）の時刻を、カードの外の左下に小さく灰色で置く（LINE と同じ）。
/// 返事と知らせには付けない。読み上げはカードの側で時刻を読むので、ここの時刻は読ませない
struct OwnRecordTime: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .accessibilityHidden(true)
    }
}

extension View {
    /// カードの左下に時刻を置き、右に寄せる
    func ownRecordTime(_ text: String) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            OwnRecordTime(text: text)
            self
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
