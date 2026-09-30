import NuToriCore

/// デバッグビルドは送らない。identify はサインインのあと、AccountSession が行う
struct ObservationSessions {
    let analytics: any AnalyticsSession
    let errorReporting: any ErrorReportingSession

    static func live() -> ObservationSessions {
        #if DEBUG
            ObservationSessions(
                analytics: SilentAnalyticsSession(),
                errorReporting: SilentErrorReportingSession()
            )
        #else
            ObservationSessions(
                analytics: GatedAnalyticsSession(forwarding: PostHogAnalyticsSession()),
                errorReporting: GatedErrorReportingSession(
                    forwarding: SentryErrorReportingSession())
            )
        #endif
    }
}

private nonisolated struct SilentAnalyticsSession: AnalyticsSession {
    func identify(accountId: String) async {}
    func capture(_ event: ClientUsageEvent) async {}
    func flushPendingEvents() async {}
    func reset() async {}
}

private nonisolated struct SilentErrorReportingSession: ErrorReportingSession {
    func identify(accountId: String) async {}
    func report(_ failure: HandledFailure) async {}
    func clearUser() async {}
}
