/// エラーの報告の送り先（Sentry）
public protocol ErrorReportingSession: Sendable {
    func identify(accountId: String) async
    func report(_ failure: HandledFailure) async
    func clearUser() async
}
