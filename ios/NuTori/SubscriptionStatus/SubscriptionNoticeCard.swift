import NuToriCore
import SwiftUI

/// 無料体験とサブスクリプションの知らせ。その日のタイムラインの先頭に置き、閉じるボタンも答えも持たない。
/// 見出しと文、あと3日と今日までだけ「サブスクリプションを見る」
struct SubscriptionNoticeCard: View {
    let notice: SubscriptionNotice
    /// 「サブスクリプションを見る」。課金画面を開く
    let openPaywall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(notice.title)
                    .font(.subheadline.weight(.semibold))
                Text(notice.body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            if notice.showsSubscriptionButton {
                // カードの中の副の操作なので、灰色のボタン（DESIGN.md の button-secondary）
                Button(SubscriptionNotice.subscriptionButtonTitle, action: openPaywall)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("subscription-notice-open-paywall")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        // DESIGN.md の timeline-card。アプリからの知らせは全幅の白いカード
        .background(
            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("subscription-notice")
    }
}
