import NuToriCore
import SwiftUI

/// ページの下の行。左下に「戻る」（2ページ目から）、右に、そのページの主な操作
struct GoalSetupFooter<Primary: View>: View {
    let page: GoalSetupPage
    let goBack: () -> Void
    @ViewBuilder let primary: () -> Primary

    var body: some View {
        HStack(spacing: 12) {
            if page != .direction {
                Button("戻る", action: goBack)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("goal-setup-back")
            }
            Spacer(minLength: 0)
            primary()
        }
    }
}
