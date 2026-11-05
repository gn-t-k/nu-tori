import NuToriCore
import SwiftUI

/// 1日の目安の出典に潜る入口。出し方のリンク（`DailyGuideExplanationLink`）のすぐ下に置き、同じ見た目にする。
/// 文字だけで見た目が小さいので、DESIGN.md の「押せる範囲は 44 以上」に合わせて押せる範囲を広げる
struct DailyGuideCitationLink: View {
    var body: some View {
        NavigationLink(value: TimelineNavigation.Route.dailyGuideCitation) {
            Text("\(DailyGuideCitationScreen.title) ›")
                .font(.footnote)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("daily-guide-citation-link")
    }
}
