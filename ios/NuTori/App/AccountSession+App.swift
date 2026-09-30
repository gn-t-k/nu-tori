import Foundation
import NuToriAPI
import NuToriCore

extension AccountSession {
    @MainActor static func forThisLaunch() -> AccountSession {
        #if DEBUG
            if let launch = UITestLaunch.current {
                return launch.accountSessionWithStubs()
            }
        #endif
        return live()
    }

    @MainActor private static func live() -> AccountSession {
        let observation = ObservationSessions.live()
        let keychain = KeychainSessionKeychain()
        return AccountSession(
            client: NuToriAPIClient(
                environment: .forThisBuild,
                sessionToken: { try? await keychain.sessionToken() }
            ),
            keychain: keychain,
            deviceStore: UserDefaultsSignInDeviceStore(defaults: .standard),
            syncStore: PlaceholderSyncStore(queuedWrites: [], hasCompletedInitialPull: true),
            appleCredentials: AppleIDCredentialChecker(),
            backgroundTransfers: PlaceholderBackgroundTransferStore(),
            healthAnchors: PlaceholderHealthAnchorStore(),
            analytics: observation.analytics,
            errorReporting: observation.errorReporting,
            timeZone: { .current },
            analyticsFlushTimeout: .seconds(3)
        )
    }
}
