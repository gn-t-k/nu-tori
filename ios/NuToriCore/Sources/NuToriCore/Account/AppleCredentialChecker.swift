public protocol AppleCredentialChecker: Sendable {
    /// 電波が無いなどで確かめられなければ投げる
    func credentialState(forAppleUserId appleUserId: String) async throws -> AppleCredentialState
}
