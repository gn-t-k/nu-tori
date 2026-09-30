import NuToriCore

final class ErrorReportingSessionMock: ErrorReportingSession, @unchecked Sendable {
    private(set) var identifiedAccountIds: [String] = []
    private(set) var reported: [HandledFailure] = []
    private(set) var clearUserCount = 0

    static func ok() -> ErrorReportingSessionMock {
        ErrorReportingSessionMock()
    }

    func identify(accountId: String) async {
        identifiedAccountIds.append(accountId)
    }

    func report(_ failure: HandledFailure) async {
        reported.append(failure)
    }

    func clearUser() async {
        clearUserCount += 1
    }
}
