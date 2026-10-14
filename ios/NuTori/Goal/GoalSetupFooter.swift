import NuToriCore
import SwiftUI

/// ページの下の行。左下に「戻る」（2ページ目から）、右に、そのページの主な操作。
/// 大きな文字で横に入らないときは、ボタンの名前が1字ずつ折れないよう、「戻る」の下に主な操作を置く
struct GoalSetupFooter<Primary: View>: View {
    let page: GoalSetupPage
    let goBack: () -> Void
    @ViewBuilder let primary: () -> Primary

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                backButton
                Spacer(minLength: 0)
                primary()
            }
            VStack(alignment: .leading, spacing: 12) {
                backButton
                primary()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    @ViewBuilder private var backButton: some View {
        if page != .direction {
            Button("戻る", action: goBack)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("goal-setup-back")
        }
    }
}
