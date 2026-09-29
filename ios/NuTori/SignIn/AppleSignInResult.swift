import AuthenticationServices
import Foundation
import NuToriCore

enum AppleSignInResult: Equatable {
    case authorized(AppleSignInCredential)
    /// iPhone の画面を閉じてやめた
    case cancelled
    case failed
}

extension AppleSignInResult {
    init(_ result: Result<ASAuthorization, any Error>, nonce: String) {
        switch result {
        case .success(let authorization):
            self = Self.authorized(authorization, nonce: nonce)
        case .failure(let error):
            self = Self.isCancellation(error) ? .cancelled : .failed
        }
    }

    private static func authorized(_ authorization: ASAuthorization, nonce: String)
        -> AppleSignInResult
    {
        // ASAuthorization は資格情報を基底の型で返すので、キャストは避けられない
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let idToken = credential.identityToken.map({ String(decoding: $0, as: UTF8.self) }),
            let authorizationCode = credential.authorizationCode.map({
                String(decoding: $0, as: UTF8.self)
            })
        else {
            return .failed
        }
        return .authorized(
            AppleSignInCredential(
                idToken: idToken,
                nonce: nonce,
                authorizationCode: authorizationCode,
                appleUserId: credential.user
            )
        )
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        // Result の失敗は any Error なので、キャストは避けられない
        (error as? ASAuthorizationError)?.code == .canceled
    }
}
