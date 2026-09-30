import NuToriCore

/// PostHog を組み込むまでの置き場
nonisolated struct PlaceholderAnalyticsSession: AnalyticsSession {
    func flushPendingEvents() async {}

    func reset() async {}
}
