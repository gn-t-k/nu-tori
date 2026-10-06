import NuToriCore

final class ErrorReportingSessionMock: ErrorReportingSession, @unchecked Sendable {
    private(set) var identifiedAccountIds: [String] = []
    struct Report {
        let failure: HandledFailure
        let cause: FailureCause?
    }

    private(set) var reports: [Report] = []
    var reported: [HandledFailure] { reports.map(\.failure) }
    private(set) var clearUserCount = 0

    static func ok() -> ErrorReportingSessionMock {
        ErrorReportingSessionMock()
    }

    func identify(accountId: String) async {
        identifiedAccountIds.append(accountId)
    }

    func report(_ failure: HandledFailure, cause: FailureCause?) async {
        reports.append(Report(failure: failure, cause: cause))
    }

    func clearUser() async {
        clearUserCount += 1
    }
}
