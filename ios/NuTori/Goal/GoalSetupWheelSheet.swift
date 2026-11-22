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
