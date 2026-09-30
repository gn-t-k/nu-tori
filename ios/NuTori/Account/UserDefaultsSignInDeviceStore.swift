import Foundation
import NuToriCore

// UserDefaults はスレッドセーフだが、この SDK では Sendable の宣言が無い
nonisolated struct UserDefaultsSignInDeviceStore: SignInDeviceStore, @unchecked Sendable {
    let defaults: UserDefaults

    func hasOpenedBefore() async throws -> Bool {
        defaults.bool(forKey: Key.hasOpened)
    }

    func markOpened() async throws {
        defaults.set(true, forKey: Key.hasOpened)
    }

    func signedInAccount() async throws -> SignedInAccount? {
        guard let accountId = defaults.string(forKey: Key.accountId),
            let appleUserId = defaults.string(forKey: Key.appleUserId)
        else {
            return nil
        }
        return SignedInAccount(accountId: accountId, appleUserId: appleUserId)
    }

    func save(_ account: SignedInAccount) async throws {
        defaults.set(account.accountId, forKey: Key.accountId)
        defaults.set(account.appleUserId, forKey: Key.appleUserId)
    }

    func hasSignInAgainMark() async throws -> Bool {
        defaults.bool(forKey: Key.signInAgainMark)
    }

    func setSignInAgainMark() async throws {
        defaults.set(true, forKey: Key.signInAgainMark)
    }

    func clearSignInAgainMark() async throws {
        defaults.removeObject(forKey: Key.signInAgainMark)
    }

    func eraseAccountBoundState() async throws {
        defaults.removeObject(forKey: Key.accountId)
        defaults.removeObject(forKey: Key.appleUserId)
        defaults.removeObject(forKey: Key.signInAgainMark)
        defaults.removeObject(forKey: Key.deviceId)
    }

    /// アプリを消すと消える場所に置く。キーチェーンは消しても残る
    func loadOrCreateDeviceId() -> UUID {
        if let saved = defaults.string(forKey: Key.deviceId), let id = UUID(uuidString: saved) {
            return id
        }
        let id = UUID()
        defaults.set(id.uuidString, forKey: Key.deviceId)
        return id
    }

    enum Key {
        static let hasOpened = "signIn.hasOpened"
        static let accountId = "signIn.accountId"
        static let appleUserId = "signIn.appleUserId"
        static let signInAgainMark = "signIn.signInAgainMark"
        static let deviceId = "sync.deviceId"
    }
}
