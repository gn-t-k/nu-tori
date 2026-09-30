import NuToriCore

final class SessionKeychainMock: SessionKeychain, @unchecked Sendable {
    private(set) var token: String?

    static func ok(token: String?, log: CallLog = CallLog()) -> SessionKeychainMock {
        SessionKeychainMock(token: token, log: log, failure: nil)
    }

    static func error(_ error: any Error) -> SessionKeychainMock {
        SessionKeychainMock(token: nil, log: CallLog(), failure: error)
    }

    func sessionToken() async throws -> String? {
        try failIfNeeded()
        return token
    }

    func save(sessionToken: String) async throws {
        try failIfNeeded()
        log.record("keychain.save")
        token = sessionToken
    }

    func deleteSessionToken() async throws {
        try failIfNeeded()
        log.record("keychain.delete")
        token = nil
    }

    private let log: CallLog
    private let failure: (any Error)?

    private init(token: String?, log: CallLog, failure: (any Error)?) {
        self.token = token
        self.log = log
        self.failure = failure
    }

    private func failIfNeeded() throws {
        if let failure { throw failure }
    }
}
