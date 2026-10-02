#if DEBUG
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: AppLockoutScreen.Sample.allCases) { sample in
        AppLockoutScreen(destination: sample.destination)
    }

    extension AppLockoutScreen {
        fileprivate enum Sample: CaseIterable {
            /// App Store から入れた版、または見分けられないとき
            case appStore
            /// TestFlight から入れた版
            case testFlight

            var destination: AppUpdateDestination {
                switch self {
                case .appStore: .appStore(appId: nil)
                case .testFlight: .testFlight
                }
            }
        }
    }
#endif
