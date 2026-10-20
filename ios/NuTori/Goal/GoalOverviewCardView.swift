import NuToriCore
import SwiftUI

/// 目標の画面の一番上の、今の目標のカード（仕様の `gcard` A）。上の行に向きと期間、大きな1行、下の行。
/// 進行中は右上に「目標を切り替える」、達成・期限・期限後の維持はカードの下に塗ったボタンを置く
struct GoalOverviewCardView: View {
    let card: GoalOverview.Card
    /// 「目標を切り替える」と塗ったボタン
    let act: (GoalOverview.Card.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 大きな文字で横に詰めると、期間が日付の途中で折り返すので、横に収まらなければ「目標を切り替える」を期間の下に置く
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    summary
                    Spacer(minLength: 0)
                    // 押せる高さは 44 のまま、見た目は上の行にそろえる。カードの上の余白に押せる範囲をはみ出させる
                    switchButton
                        .padding(.vertical, -12)
                }
                VStack(alignment: .leading, spacing: 0) {
                    summary
                    switchButton
                }
            }
            Text(card.title)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("goal-card-title")
            if let detail = card.detail {
                Text(detail)
                    .font(card.action == .switchGoal ? .subheadline : .footnote)
                    .foregroundStyle(card.action == .switchGoal ? .primary : .secondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("goal-card-detail")
            }
            if let lateAchievement = card.lateAchievement {
                Text(lateAchievement)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let label = filledLabel {
                Button(label) {
                    act(card.action)
                }
                .buttonStyle(.borderedProminent)
                .font(.subheadline.weight(.semibold))
                .padding(.top, 6)
                .accessibilityIdentifier("goal-card-action")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("goal-card")
    }

    /// 「減量 9月1日〜11月30日」
    private var summary: some View {
        Text(card.summary)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 進行中だけ置く「目標を切り替える」
    @ViewBuilder private var switchButton: some View {
        if card.action == .switchGoal {
            Button {
                act(.switchGoal)
            } label: {
                // 期間の下に置いて折り返すとき、期間と左をそろえる
                Text("目標を切り替える")
                    .multilineTextAlignment(.leading)
            }
            .font(.subheadline)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityIdentifier("goal-switch")
        }
    }

    /// 塗ったボタンの文字。進行中は右上の文字のボタンにするので nil
    private var filledLabel: String? {
        switch card.action {
        case .switchGoal: nil
        case .chooseNextGoal: "次の目標を選ぶ"
        case .setNextGoal: "次の目標を立てる"
        }
    }
}
