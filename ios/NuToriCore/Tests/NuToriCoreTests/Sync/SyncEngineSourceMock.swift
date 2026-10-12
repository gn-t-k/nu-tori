import NuToriCore

/// サインインしている端末の、同期の働きを作るもの
final class SyncEngineSourceMock: SyncEngineSource, Sendable {
    /// `engine` は、アカウント ID から同期の働きを作る
    static func ok(
        accountId: String, engine: @escaping @Sendable (String) -> SyncEngine
    ) -> SyncEngineSourceMock {
        SyncEngineSourceMock(accountId: accountId, makeEngine: engine)
    }

    func hasSession() async -> Bool {
        true
    }

    func signedInAccountId() async -> String? {
        accountId
    }

    func engine(accountId: String) async -> SyncEngine {
        makeEngine(accountId)
    }

    private let accountId: String
    private let makeEngine: @Sendable (String) -> SyncEngine

    private init(accountId: String, makeEngine: @escaping @Sendable (String) -> SyncEngine) {
        self.accountId = accountId
        self.makeEngine = makeEngine
    }
}
