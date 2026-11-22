import SwiftUI

/// 足りない値のページの、ホイールで選ぶ値の行。行のどこを押してもホイールのシートを出す。入れるまで行の右は「選ぶ」
struct GoalSetupWheelRow: View {
    let label: String
    /// 入れた値の文。入れていなければ nil
    let value: String?
    let identifier: String
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            GoalSetupLabeledRow(label) {
                Text(value ?? "選ぶ")
                    .foregroundStyle(value == nil ? Color.accentColor : .primary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(value ?? "選ぶ")
        .accessibilityIdentifier(identifier)
    }
}
