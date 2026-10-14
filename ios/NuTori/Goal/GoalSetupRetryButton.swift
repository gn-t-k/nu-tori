import SwiftUI

/// つながらなかった要求をもう一度出す
struct GoalSetupRetryButton: View {
    let retry: () -> Void

    var body: some View {
        Button("もう一度試す", action: retry)
            .buttonStyle(.bordered)
            .accessibilityIdentifier("goal-setup-retry")
    }
}
