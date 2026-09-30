import NuToriCore

/// UI テストは観測に送らない
nonisolated struct PlaceholderAnalyticsSession: AnalyticsSession {
    func identify(accountId: String) async {}

    func capture(_ event: ClientUsageEvent) async {}

    func flushPendingEvents() async {}

    func reset() async {}
}
