import NuToriCore
import StoreKit

extension AppUpdateDestination {
    /// どこから入れた版かを、StoreKit の `AppTransaction` の環境で見分ける。見分けられないときは App Store
    static func forThisInstall() async -> AppUpdateDestination {
        #if DEBUG
            // デバッグビルドは App Store からも TestFlight からも入らない。
            // シミュレーターと UI テストで App Store のサインインを求められないよう、尋ねずに App Store にする
            return .appStore(appId: nil)
        #else
            guard let transaction = try? await AppTransaction.shared.unsafePayloadValue else {
                return .appStore(appId: nil)
            }
            // TestFlight から入れた版は、sandbox の環境になる
            if transaction.environment == .sandbox {
                return .testFlight
            }
            return .appStore(appId: transaction.appID)
        #endif
    }
}
