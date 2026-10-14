import NuToriAPI
import NuToriCore
import SwiftUI

/// 向きのページ。押すとすぐ次へ進む。初めてでまだ求めていない種類があれば、流れが iPhone の許可の画面を出す（自前の説明画面は作らない）
struct GoalSetupDirectionPage: View {
    let content: GoalSetupFlowContent
    let actions: GoalSetupFlowActions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("何を目指しますか")
                .font(.headline)
            VStack(spacing: 8) {
                row(.lose, detail: "体重を減らす")
                row(.maintain, detail: "今の体重を保つ")
                row(.gain, detail: "体重を増やす")
            }
        }
    }

    private func row(_ direction: GoalSetupDirection, detail: String) -> some View {
        Button {
            actions.chooseDirection(direction)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(GoalDirectionText.name(direction))
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                // 戻ってきたときに、前に選んだ向きが分かるように
                Image(systemName: content.direction == direction ? "checkmark" : "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(
                        content.direction == direction ? Color.accentColor : Color(.tertiaryLabel))
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            // DESIGN.md の value-field と同じ Fill の地。カードの白の上で、押せる行と分かるように
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(content.direction == direction ? .isSelected : [])
        .accessibilityIdentifier("goal-setup-direction-\(direction.rawValue)")
    }
}
