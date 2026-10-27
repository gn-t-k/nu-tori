import NuToriAPI
import NuToriCore
import SwiftUI

/// 維持のページ。大きな「65.0 kg を保つ」と値の行「1日の目安　2,250 kcal」と、塗ったボタン「維持で始める」。
/// 値（目標体重は開始の日の体重の傾向）は目標案の要求で受け取り、届くまではその場に回る印を出す
struct GoalSetupMaintenancePage: View {
    let content: GoalSetupFlowContent
    let actions: GoalSetupFlowActions

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if case .maintenance(let maintenance)? = content.proposals?.plan {
                Group {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(WeightAmountText.kilograms(maintenance.targetWeightKilograms)) を保つ")
                            .font(.title2.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        GoalSetupValueRow(
                            label: "1日の目安",
                            value: NutritionText.kilocalories(
                                maintenance.dailyGuide.energyKilocalories))
                    }
                    .monospacedDigit()
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("goal-setup-maintenance")
                    if content.showsRecalculated {
                        GoalSetupRecalculatedNote()
                    }
                }
                .dimmedWhileDeciding(content.isDeciding)
                if content.unreachableRequest == .decision {
                    Text(GoalSetupUnreachableText.decision)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("goal-setup-unreachable")
                }
                GoalSetupMedicalNote(isDeciding: content.isDeciding)
                GoalSetupStartButton(
                    title: "維持で始める", identifier: "goal-setup-maintain-start",
                    isDeciding: content.isDeciding, decide: actions.decide)
                GoalSetupFooter(page: content.page, goBack: actions.goBack) {
                    if content.unreachableRequest == .decision {
                        GoalSetupRetryButton(retry: actions.retry)
                    }
                }
                .dimmedWhileDeciding(content.isDeciding)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
                GoalSetupFooter(page: content.page, goBack: actions.goBack) { EmptyView() }
            }
        }
    }
}
