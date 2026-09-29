public struct SignedInAccount: Sendable, Equatable {
    /// nu-tori のアカウント ID。別のアカウントかの見分けに使う
    public let accountId: String
    /// Sign in with Apple で得た user の識別子。`getCredentialState` に渡す
    public let appleUserId: String

    public init(accountId: String, appleUserId: String) {
        self.accountId = accountId
        self.appleUserId = appleUserId
    }
}
