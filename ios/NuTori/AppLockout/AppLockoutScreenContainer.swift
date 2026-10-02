import NuToriCore
import SwiftUI

/// どこから入れた版かを見分けて、締め出しの画面に渡す
struct AppLockoutScreenContainer: View {
    var body: some View {
        AppLockoutScreen(
            destination: destination ?? .appStore(appId: nil),
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
    /// どこから入れた版か。見分け終えるまでは nil で、ボタンの名前は見分けられないときと同じ App Store にする
    @State private var destination: AppUpdateDestination?
}
