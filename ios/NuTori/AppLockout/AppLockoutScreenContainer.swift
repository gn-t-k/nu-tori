import NuToriCore
import SwiftUI

/// どこから入れた版かを見分けて、締め出しの画面の更新のボタンで開く先にする
struct AppLockoutScreenContainer: View {
    var body: some View {
        AppLockoutScreen(
            isOpening: false,
            openUpdate: {
                // 見分け終える前に押されたら、見分け終えるのを待って開く。TestFlight の版で App Store を開かないため
                let resolved: AppUpdateDestination
                if let destination {
                    resolved = destination
                } else {
                    resolved = await AppUpdateDestination.forThisInstall()
                }
                openURL(resolved.url)
            }
        )
        .task {
            destination = await AppUpdateDestination.forThisInstall()
        }
    }

    @Environment(\.openURL) private var openURL
    /// どこから入れた版か。見分け終えるまでは nil
    @State private var destination: AppUpdateDestination?
}
