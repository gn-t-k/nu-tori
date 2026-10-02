import NuToriCore
import SwiftUI

/// どこから入れた版かを見分けて、締め出しの画面に渡す
struct AppLockoutScreenContainer: View {
    var body: some View {
        AppLockoutScreen(destination: destination)
            .task {
                destination = await AppUpdateDestination.forThisInstall()
            }
    }

    /// 見分け終えるまでは、見分けられないときと同じ App Store にする
    @State private var destination = AppUpdateDestination.appStore(appId: nil)
}
