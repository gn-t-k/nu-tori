import NuToriCore

final class ErrorReportingSessionMock: ErrorReportingSession, @unchecked Sendable {
    private(set) var clearUserCount = 0

    static func ok() -> ErrorReportingSessionMock {
        ErrorReportingSessionMock()
    }

    func clearUser() async {
        clearUserCount += 1
    }
}
