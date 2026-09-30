public struct AppleSignInCredential: Sendable, Equatable {
    public let idToken: String
    /// ID トークンに入っているのと同じ値。Apple の要求にハッシュを渡したなら、そのハッシュ
    public let nonce: String
    public let authorizationCode: String
    public let appleUserId: String

    public init(idToken: String, nonce: String, authorizationCode: String, appleUserId: String) {
        self.idToken = idToken
        self.nonce = nonce
        self.authorizationCode = authorizationCode
        self.appleUserId = appleUserId
    }
}
