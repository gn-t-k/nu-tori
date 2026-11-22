import SwiftUI

/// 足りない値のホイールのシート。「完了」で入れて閉じ、「キャンセル」か下げると入れずに閉じる
struct GoalSetupWheelSheet<Wheels: View>: View {
    let title: String
    let confirm: () -> Void
    @ViewBuilder let wheels: () -> Wheels
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                wheels()
            }
            .padding(.horizontal)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .accessibilityIdentifier("goal-setup-wheel-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        confirm()
                        dismiss()
                    }
                    .accessibilityIdentifier("goal-setup-wheel-confirm")
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// シートに並べるホイールの1本
struct GoalSetupWheel<Choices: View>: View {
    let label: String
    @Binding var selection: Int
    let identifier: String
    @ViewBuilder let choices: () -> Choices

    init(
        _ label: String, selection: Binding<Int>, identifier: String,
        @ViewBuilder choices: @escaping () -> Choices
    ) {
        self.label = label
        _selection = selection
        self.identifier = identifier
        self.choices = choices
    }

    var body: some View {
        Picker(label, selection: $selection, content: choices)
            .pickerStyle(.wheel)
            .labelsHidden()
            // 2本並べたとき、互いの押せる範囲が重ならないよう、幅を分けて切る
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityIdentifier(identifier)
    }
}
