import NuToriCore

/// UI テストは観測に送らない
nonisolated struct PlaceholderErrorReportingSession: ErrorReportingSession {
    func identify(accountId: String) async {}

    func report(_ failure: HandledFailure, cause: FailureCause?) async {}

    func clearUser() async {}
}
