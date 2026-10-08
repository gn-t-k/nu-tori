import Foundation

extension Bundle {
    /// アプリの版（`CFBundleShortVersionString`）。読めないときは 0
    nonisolated var appVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}
