import NuToriCore

final class SessionKeychainMock: SessionKeychain, @unchecked Sendable {
    private(set) var token: String?

    static func ok(token: String? = nil, log: CallLog = CallLog()) -> SessionKeychainMock {
        SessionKeychainMock(token: token, log: log)
    }

    func sessionToken() async throws -> String? {
        token
    }

    func save(sessionToken: String) async throws {
        log.record("keychain.save")
        token = sessionToken
    }

    func deleteSessionToken() async throws {
        log.record("keychain.delete")
        token = nil
    }

    private let log: CallLog

    private init(token: String?, log: CallLog) {
        self.token = token
        self.log = log
    }
}
