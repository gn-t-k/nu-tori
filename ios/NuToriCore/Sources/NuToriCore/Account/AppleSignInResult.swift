/// Sign in with Apple の結果。Apple の資格情報からの読み取りは、アプリのターゲットが持つ
public enum AppleSignInResult: Equatable, Sendable {
    case authorized(AppleSignInCredential)
    case cancelled
    case failed
}
