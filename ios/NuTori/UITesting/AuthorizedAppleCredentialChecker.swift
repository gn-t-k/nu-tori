#if DEBUG
    import NuToriCore

    nonisolated struct AuthorizedAppleCredentialChecker: AppleCredentialChecker {
        func credentialState(forAppleUserId appleUserId: String) async throws
            -> AppleCredentialState
        {
            .authorized
        }
    }
#endif
