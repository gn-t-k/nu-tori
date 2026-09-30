import NuToriCore

/// Sentry を組み込むまでの置き場
nonisolated struct PlaceholderErrorReportingSession: ErrorReportingSession {
    func clearUser() async {}
}
