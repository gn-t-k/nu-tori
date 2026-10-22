import SwiftUI

/// 文字だけで見た目が小さいので、DESIGN.md の「押せる範囲は 44 以上」に合わせて押せる範囲を広げる
struct DailyGuideExplanationLink: View {
    var body: some View {
        Link("推定消費カロリーと1日の目安の出し方", destination: PublicPages.dailyGuide)
            .font(.footnote)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityIdentifier("daily-guide-explanation-link")
    }
}
