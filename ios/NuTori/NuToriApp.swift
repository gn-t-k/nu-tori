import SwiftData
import SwiftUI

@main
struct NuToriApp: App {
    init() {
        runtime?.recordSync.registerAndWatch()
    }

    var body: some Scene {
        WindowGroup {
            if let runtime {
                RootView(model: runtime.model, appLockout: runtime.appLockout)
                    .modelContainer(runtime.container)
                    #if DEBUG
                        .environment(
                            \.stubbedAppleSignInResult, UITestLaunch.current?.appleSignInResult)
                    #endif
            } else {
                storeUnopened
            }
        }
    }

    private let runtime = AppRuntime.forThisLaunch()

    private var storeUnopened: some View {
        VStack {
            ProgressView()
            Text("記録を読み込んでいます…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
