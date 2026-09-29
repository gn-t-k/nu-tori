import NuToriCore

final class SignInDeviceStoreMock: SignInDeviceStore, @unchecked Sendable {
    private(set) var hasOpened: Bool
    private(set) var account: SignedInAccount?
    private(set) var hasMark: Bool
    private(set) var didEraseAccountBoundState = false

    static func ok(
        hasOpenedBefore: Bool = true,
        account: SignedInAccount? = nil,
        hasSignInAgainMark: Bool = false,
        log: CallLog = CallLog()
    ) -> SignInDeviceStoreMock {
        SignInDeviceStoreMock(
            hasOpened: hasOpenedBefore, account: account, hasMark: hasSignInAgainMark, log: log)
    }

    func hasOpenedBefore() async throws -> Bool {
        hasOpened
    }

    func markOpened() async throws {
        hasOpened = true
    }

    func signedInAccount() async throws -> SignedInAccount? {
        account
    }

    func save(_ account: SignedInAccount) async throws {
        log.record("deviceStore.save")
        self.account = account
    }

    func hasSignInAgainMark() async throws -> Bool {
        hasMark
    }

    func setSignInAgainMark() async throws {
        hasMark = true
    }

    func clearSignInAgainMark() async throws {
        hasMark = false
    }

    func eraseAccountBoundState() async throws {
        log.record("deviceStore.erase")
        account = nil
        hasMark = false
        didEraseAccountBoundState = true
    }

    private let log: CallLog

    private init(hasOpened: Bool, account: SignedInAccount?, hasMark: Bool, log: CallLog) {
        self.hasOpened = hasOpened
        self.account = account
        self.hasMark = hasMark
        self.log = log
    }
}
