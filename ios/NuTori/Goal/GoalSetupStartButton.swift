import SwiftUI

/// 「この目標で始める」「維持で始める」。押すと、ボタンの中に回る印を文字と並べて出す（DESIGN.md の「待っている表示」）
struct GoalSetupStartButton: View {
    let title: String
    let identifier: String
    let isDeciding: Bool
    let decide: () -> Void

    var body: some View {
        Button(action: decide) {
            HStack(spacing: 8) {
                if isDeciding {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityIdentifier(identifier)
    }
}
