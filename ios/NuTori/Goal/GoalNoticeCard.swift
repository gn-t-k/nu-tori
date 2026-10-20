import NuToriCore
import SwiftUI

/// 目標の達成・期限・期限後の維持の知らせ（仕様の `notices` B）。見出しと時刻、本文、右下に塗ったボタン1つ。
/// 答えを持たないので「あとで」を置かない。今の目標でなくなった目標の知らせは、ボタンを押せなくし、すぐ下に理由の1行を添える（DESIGN.md の「押せないボタン」）
struct GoalNoticeCard: View {
    let notice: GoalNotice
    /// 「次の目標を選ぶ」「次の目標を立てる」。立て直す流れを開く
    let open: (GoalSetupObservation.Entry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(notice.headline)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text(
                    WeightAmountText.clock(
                        ClockTime(containing: notice.issuedAt, in: notice.timeZone))
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Text(notice.body)
                .font(.subheadline)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .trailing, spacing: 6) {
                Button(notice.actionTitle) {
                    open(notice.setupEntry)
                }
                .buttonStyle(.borderedProminent)
                .disabled(notice.unavailableText != nil)
                .accessibilityIdentifier("goal-notice-action")
                if let unavailableText = notice.unavailableText {
                    Text(unavailableText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("goal-notice-unavailable")
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        // DESIGN.md の timeline-card。アプリからの知らせは全幅の白いカード
        .background(
            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("goal-notice")
    }
}
