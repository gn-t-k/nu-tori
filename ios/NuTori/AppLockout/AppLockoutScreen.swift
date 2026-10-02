import NuToriCore
import SwiftUI

/// 締め出しの画面。すべての画面に替えて全面に出し、説明と更新のボタンだけを載せる
struct AppLockoutScreen: View {
    /// ボタンの名前に出す、更新する場所
    let destination: AppUpdateDestination
    /// 更新する場所を開く
    let openUpdate: () async -> Void

    var body: some View {
        // 文字を大きくして入りきらないときだけ、全体を送れるようにする
        ViewThatFits(in: .vertical) {
            content
            ScrollView {
                content
            }
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("app-lockout")
    }

    private var content: some View {
        VStack(spacing: 24) {
            message
                .frame(maxHeight: .infinity)
            Button {
                Task { await openUpdate() }
            } label: {
                Text(buttonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
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
    }

    private var buttonTitle: String {
        switch destination {
        case .appStore: "App Store で更新"
        case .testFlight: "TestFlight で更新"
        }
    }
}
