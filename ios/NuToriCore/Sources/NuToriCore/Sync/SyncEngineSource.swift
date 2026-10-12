/// この端末の同期の働きを作るもの。サインインしているかも、ここから読む
public protocol SyncEngineSource: Sendable {
    func hasSession() async -> Bool

    func signedInAccountId() async -> String?

    func engine(accountId: String) async -> SyncEngine
}
