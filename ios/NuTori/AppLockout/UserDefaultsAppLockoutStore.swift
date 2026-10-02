import Foundation
import NuToriCore

// UserDefaults はスレッドセーフだが、この SDK では Sendable の宣言が無い
nonisolated struct UserDefaultsAppLockoutStore: AppLockoutStore, @unchecked Sendable {
    let defaults: UserDefaults

    func lockedOutBuild() -> Int? {
        defaults.object(forKey: Key.lockedOutBuild) == nil
            ? nil : defaults.integer(forKey: Key.lockedOutBuild)
    }

    func remember(lockedOutBuild build: Int) {
        defaults.set(build, forKey: Key.lockedOutBuild)
    }

    func forget() {
        defaults.removeObject(forKey: Key.lockedOutBuild)
    }

    enum Key {
        static let lockedOutBuild = "appLockout.lockedOutBuild"
    }
}
