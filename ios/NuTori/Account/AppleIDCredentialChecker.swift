import AuthenticationServices
import NuToriCore

nonisolated struct AppleIDCredentialChecker: AppleCredentialChecker {
    func credentialState(forAppleUserId appleUserId: String) async throws -> AppleCredentialState {
        let state = try await ASAuthorizationAppleIDProvider().credentialState(
            forUserID: appleUserId)
        switch state {
        case .authorized: return .authorized
        case .revoked: return .revoked
        case .notFound: return .notFound
        case .transferred: return .transferred
        @unknown default: throw UnknownCredentialStateError()
        }
    }

    struct UnknownCredentialStateError: Error {}
}
