import NuToriAPI
import NuToriCore
import SwiftUI

/// 維持のページ。「65.0 kg を保ちます。1日の目安は 2,250 kcal です。」と塗ったボタン「維持で始める」。
/// 値（目標体重は開始の日の体重の傾向）は目標案の要求で受け取り、届くまではその場に回る印を出す
struct GoalSetupMaintenancePage: View {
    let content: GoalSetupFlowContent
    let actions: GoalSetupFlowActions

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if case .maintenance(let maintenance)? = content.proposals?.plan {
                Group {
                    Text(
                        "\(WeightAmountText.kilograms(maintenance.targetWeightKilograms)) を保ちます。1日の目安は \(NutritionText.kilocalories(maintenance.dailyGuide.energyKilocalories)) です。"
                    )
                    .font(.subheadline)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("goal-setup-maintenance")
                    if content.showsRecalculated {
                        GoalSetupRecalculatedNote()
                    }
                }
                // DESIGN.md の押せないボタン（`.disabled` に任せる）に従わず、文と値も薄くする。仕様 #523 の「決める」が、押したら「ほかを薄くして」と決めているため
                .opacity(content.isDeciding ? 0.4 : 1)
                if content.unreachableRequest == .decision {
                    Text(GoalSetupUnreachableText.decision)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("goal-setup-unreachable")
                }
                GoalSetupStartButton(
                    title: "維持で始める", identifier: "goal-setup-maintain-start",
                    isDeciding: content.isDeciding, decide: actions.decide)
                GoalSetupFooter(page: content.page, goBack: actions.goBack) {
                    if content.unreachableRequest == .decision {
                        GoalSetupRetryButton(retry: actions.retry)
                    }
                }
                .opacity(content.isDeciding ? 0.4 : 1)
                .disabled(content.isDeciding)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
                GoalSetupFooter(page: content.page, goBack: actions.goBack) { EmptyView() }
            }
        }
    }
}
