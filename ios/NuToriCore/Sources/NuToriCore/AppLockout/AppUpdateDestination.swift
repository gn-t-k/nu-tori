public import Foundation

/// 締め出しの画面のボタンで開く、更新する場所。どこから入れた版かは、アプリが StoreKit の `AppTransaction` の環境で見分ける
public enum AppUpdateDestination: Sendable, Equatable {
    /// App Store の版、または見分けられないとき（デバッグビルドなど）。
    /// appId は App Store がアプリに振る番号（`AppTransaction.appID`）で、App Store から入れた版でないと分からない
    case appStore(appId: UInt64?)
    case testFlight

    public var url: URL {
        switch self {
        case .appStore(let appId?):
            URL(string: "https://apps.apple.com/app/id\(appId)")!
        case .appStore(nil):
            URL(string: "itms-apps://apps.apple.com")!
        case .testFlight:
            URL(string: "itms-beta://")!
        }
    }
}
