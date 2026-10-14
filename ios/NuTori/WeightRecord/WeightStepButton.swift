import SwiftUI

/// 体重の − と ＋（DESIGN.md の stepper-button）。長押しで続けて動かす
struct WeightStepButton: View {
    let title: String
    let label: String
    let enabled: Bool
    let step: () -> Void

    var body: some View {
        Button(action: stepOnce) {
            Text(title)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color(.tertiarySystemFill), in: WeightControlShape())
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .onLongPressGesture(minimumDuration: 0.4, pressing: updatePress, perform: {})
        .onDisappear {
            stepTask?.cancel()
        }
    }

    @State private var stepTask: Task<Void, Never>?
    @State private var steppedFromPress = false

    private func stepOnce() {
        if steppedFromPress {
            steppedFromPress = false
            return
        }
        step()
    }

    private func updatePress(_ pressing: Bool) {
        if pressing {
            guard enabled, stepTask == nil else { return }
            steppedFromPress = true
            step()
            stepTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                while !Task.isCancelled {
                    step()
                    try? await Task.sleep(for: .milliseconds(90))
                }
            }
        } else {
            stepTask?.cancel()
            stepTask = nil
        }
    }
}
