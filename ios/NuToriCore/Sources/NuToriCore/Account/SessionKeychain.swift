/// キーチェーンに置くのは、セッションのトークンだけ
public protocol SessionKeychain: Sendable {
    func sessionToken() async throws -> String?
    func save(sessionToken: String) async throws
    func deleteSessionToken() async throws
}
