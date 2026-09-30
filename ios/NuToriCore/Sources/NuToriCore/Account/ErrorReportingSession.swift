/// エラーの報告の送り先（Sentry）
public protocol ErrorReportingSession: Sendable {
    func clearUser() async
}
