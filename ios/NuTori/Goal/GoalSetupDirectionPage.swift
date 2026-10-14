import NuToriAPI
import NuToriCore
import SwiftUI

/// 向きのページ。押すとすぐ次へ進む。初めてでまだ求めていない種類があれば、流れが iPhone の許可の画面を出す（自前の説明画面は作らない）
struct GoalSetupDirectionPage: View {
    let flow: GoalSetupFlow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("何を目指しますか")
                .font(.headline)
            VStack(spacing: 8) {
                row(.lose, name: "減量", detail: "体重を減らす")
                row(.maintain, name: "維持", detail: "今の体重を保つ")
                row(.gain, name: "増量", detail: "体重を増やす")
            }
        }
    }

    private func row(_ direction: GoalSetupDirection, name: String, detail: String) -> some View {
        Button {
            Task { await flow.chooseDirection(direction) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                // 戻ってきたときに、前に選んだ向きが分かるように
                Image(systemName: flow.direction == direction ? "checkmark" : "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(
                        flow.direction == direction ? Color.accentColor : Color(.tertiaryLabel))
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            // DESIGN.md の value-field と同じ Fill の地。カードの白の上で、押せる行と分かるように
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(flow.direction == direction ? .isSelected : [])
        .accessibilityIdentifier("goal-setup-direction-\(direction.rawValue)")
    }
}
