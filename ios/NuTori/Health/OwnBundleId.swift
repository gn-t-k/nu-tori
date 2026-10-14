import Foundation

/// nu-tori 自身の Bundle ID。ヘルスケアの記録のうち、nu-tori が書いたものを見分ける
nonisolated enum OwnBundleId {
    static let value = Bundle.main.bundleIdentifier ?? "app.nu-tori"
}
