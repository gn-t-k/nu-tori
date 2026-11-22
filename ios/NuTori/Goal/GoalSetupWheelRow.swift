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
                // 押してシートで直せる値なので、入れたあとも Primary で描く（DESIGN.md の list-row-editable-value）
                Text(value ?? "選ぶ")
                    .foregroundStyle(Color.accentColor)
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
