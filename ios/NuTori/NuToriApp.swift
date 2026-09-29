import SwiftData
import SwiftUI

@main
struct NuToriApp: App {
    init() {
        runtime.recordSync.registerAndWatch()
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: runtime.model)
                .modelContainer(runtime.container)
                .tint(.indigo)
                #if DEBUG
                    .environment(
                        \.stubbedAppleSignInResult, UITestLaunch.current?.appleSignInResult)
                #endif
        }
    }

    private let runtime = AppRuntime.forThisLaunch()
}
