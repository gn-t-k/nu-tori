import NuToriCore

final class SignInDeviceStoreMock: SignInDeviceStore, @unchecked Sendable {
    private(set) var hasOpened: Bool
    private(set) var account: SignedInAccount?
    private(set) var hasMark: Bool
    private(set) var didEraseAccountBoundState = false

    static func ok(
        hasOpenedBefore: Bool = true,
        account: SignedInAccount?,
        hasSignInAgainMark: Bool = false,
        log: CallLog = CallLog()
    ) -> SignInDeviceStoreMock {
        SignInDeviceStoreMock(
            hasOpened: hasOpenedBefore,
            account: account,
            hasMark: hasSignInAgainMark,
            log: log,
            failure: nil
        )
    }

    static func error(_ error: any Error) -> SignInDeviceStoreMock {
        SignInDeviceStoreMock(
            hasOpened: false, account: nil, hasMark: false, log: CallLog(), failure: error)
    }

    func hasOpenedBefore() async throws -> Bool {
        try failIfNeeded()
        return hasOpened
    }

    func markOpened() async throws {
        try failIfNeeded()
        hasOpened = true
    }

    func signedInAccount() async throws -> SignedInAccount? {
        try failIfNeeded()
        return account
    }

    func save(_ account: SignedInAccount) async throws {
        try failIfNeeded()
        log.record("deviceStore.save")
        self.account = account
    }

    func hasSignInAgainMark() async throws -> Bool {
        try failIfNeeded()
        return hasMark
    }

    func setSignInAgainMark() async throws {
        try failIfNeeded()
        hasMark = true
    }

    func clearSignInAgainMark() async throws {
        try failIfNeeded()
        hasMark = false
    }

    func eraseAccountBoundState() async throws {
        try failIfNeeded()
        log.record("deviceStore.erase")
        account = nil
        hasMark = false
        didEraseAccountBoundState = true
    }

    private let log: CallLog
    private let failure: (any Error)?

    private init(
        hasOpened: Bool,
        account: SignedInAccount?,
        hasMark: Bool,
        log: CallLog,
        failure: (any Error)?
    ) {
        self.hasOpened = hasOpened
        self.account = account
        self.hasMark = hasMark
        self.log = log
        self.failure = failure
    }

    private func failIfNeeded() throws {
        if let failure { throw failure }
    }
}
