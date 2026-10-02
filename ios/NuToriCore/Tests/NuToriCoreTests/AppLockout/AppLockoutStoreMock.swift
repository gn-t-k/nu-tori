import NuToriCore

final class AppLockoutStoreMock: AppLockoutStore, @unchecked Sendable {
    private(set) var build: Int?

    /// - Parameter lockedOutBuild: 締め出されたことを覚えているビルド番号。覚えていなければ nil
    static func ok(lockedOutBuild: Int?) -> AppLockoutStoreMock {
        AppLockoutStoreMock(build: lockedOutBuild)
    }

    func lockedOutBuild() -> Int? {
        build
    }

    func remember(lockedOutBuild build: Int) {
        self.build = build
    }

    func forget() {
        build = nil
    }

    private init(build: Int?) {
        self.build = build
    }
}
