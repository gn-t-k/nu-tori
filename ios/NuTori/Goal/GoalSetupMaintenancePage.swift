import NuToriAPI
import NuToriCore
import SwiftUI

/// 維持のページ。「65.0 kg を保ちます。1日の目安は 2,250 kcal です。」と塗ったボタン「維持で始める」。
/// 値（目標体重は開始の日の体重の傾向）は目標案の要求で受け取り、届くまではその場に回る印を出す
struct GoalSetupMaintenancePage: View {
    let flow: GoalSetupFlow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if case .maintenance(let maintenance)? = flow.proposals?.plan {
                Group {
                    Text(
                        "\(WeightAmountText.kilograms(maintenance.targetWeightKilograms)) を保ちます。1日の目安は \(NutritionText.amount(.exactly(Double(maintenance.dailyGuide.energyKilocalories)), of: .energyKcal)) です。"
                    )
                    .font(.subheadline)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("goal-setup-maintenance")
                    if flow.showsRecalculated {
                        Text("新しい体重で計算し直しました。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .opacity(isDeciding ? 0.4 : 1)
                if flow.unreachableRequest == .decision {
                    Text(GoalSetupUnreachableText.decision)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("goal-setup-unreachable")
                }
                startButton
                GoalSetupFooter(flow: flow) {
                    if flow.unreachableRequest == .decision {
                        GoalSetupRetryButton(flow: flow)
                    }
                }
                .opacity(isDeciding ? 0.4 : 1)
                .disabled(isDeciding)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
                GoalSetupFooter(flow: flow) { EmptyView() }
            }
        }
    }

    private var isDeciding: Bool {
        flow.decision != .idle
    }

    /// 押すと、ボタンの中に回る印を文字と並べて出す（DESIGN.md の「待っている表示」）
    private var startButton: some View {
        Button {
            Task { await flow.decide() }
        } label: {
            HStack(spacing: 8) {
                if isDeciding {
                    ProgressView()
                        .tint(.white)
                }
                Text("維持で始める")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityIdentifier("goal-setup-maintain-start")
    }
}
