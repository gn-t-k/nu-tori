/// `ASAuthorizationAppleIDProvider.getCredentialState` の結果
public enum AppleCredentialState: Sendable, Equatable {
    case authorized
    case revoked
    case notFound
    case transferred
}
