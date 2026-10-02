import NuToriCore
import SwiftUI

/// 締め出しの画面。すべての画面に替えて全面に出し、説明と更新のボタンだけを載せる
struct AppLockoutScreen: View {
    /// ボタンの名前に出す、更新する場所
    let destination: AppUpdateDestination
    /// 更新する場所を開く
    let openUpdate: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 文字を大きくして入りきらないときは、更新のボタンをいつも画面の下に見せるため、説明だけを送る
            ViewThatFits(in: .vertical) {
                message
                    .frame(maxHeight: .infinity)
                ScrollView {
                    message
                }
            }
            Button {
                Task { await openUpdate() }
            } label: {
                Text(buttonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding([.horizontal, .bottom])
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("app-lockout")
    }

    private var message: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.up.circle")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("アップデートしてください")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("このバージョンの nu-tori は使えなくなりました。最新のバージョンに更新すると、続けて使えます。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var buttonTitle: String {
        switch destination {
        case .appStore: "App Store で更新"
        case .testFlight: "TestFlight で更新"
        }
    }
}
