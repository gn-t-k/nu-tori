import Foundation
import NuToriAPI
import NuToriCore

extension AccountSession {
    @MainActor static func forThisLaunch() -> AccountSession {
        #if DEBUG
            if let launch = UITestLaunch.current {
                return launch.makeAccountSession()
            }
        #endif
        return live()
    }

    @MainActor private static func live() -> AccountSession {
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
            analytics: PlaceholderAnalyticsSession(),
            errorReporting: PlaceholderErrorReportingSession(),
            timeZone: { .current },
            analyticsFlushTimeout: .seconds(3)
        )
    }
}
