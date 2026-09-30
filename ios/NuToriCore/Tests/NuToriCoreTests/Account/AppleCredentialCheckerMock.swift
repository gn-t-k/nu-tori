import NuToriCore

final class AppleCredentialCheckerMock: AppleCredentialChecker, @unchecked Sendable {
    private(set) var checkedAppleUserIds: [String] = []

    static func ok(_ state: AppleCredentialState = .authorized) -> AppleCredentialCheckerMock {
        AppleCredentialCheckerMock(result: .success(state))
    }

    static func error(_ error: any Error) -> AppleCredentialCheckerMock {
        AppleCredentialCheckerMock(result: .failure(error))
    }

    func credentialState(forAppleUserId appleUserId: String) async throws -> AppleCredentialState {
        checkedAppleUserIds.append(appleUserId)
        return try result.get()
    }

    private let result: Result<AppleCredentialState, any Error>

    private init(result: Result<AppleCredentialState, any Error>) {
        self.result = result
    }
}
