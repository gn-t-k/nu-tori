import SwiftUI

@main
struct NuToriApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .tint(.indigo)
                #if DEBUG
                    .environment(
                        \.stubbedAppleSignInResult, UITestLaunch.current?.appleSignInResult)
                #endif
        }
    }

    @State private var model = RootModel(accountSession: .forThisLaunch())
}
