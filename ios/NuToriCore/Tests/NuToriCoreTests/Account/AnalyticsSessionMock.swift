import NuToriCore

final class AnalyticsSessionMock: AnalyticsSession, @unchecked Sendable {
    private(set) var identifiedAccountIds: [String] = []
    private(set) var captured: [ClientUsageEvent] = []
    private(set) var flushCount = 0
    private(set) var resetCount = 0

    static func ok(log: CallLog = CallLog()) -> AnalyticsSessionMock {
        AnalyticsSessionMock(neverFlushes: false, log: log)
    }

    static func neverFlushes(log: CallLog = CallLog()) -> AnalyticsSessionMock {
        AnalyticsSessionMock(neverFlushes: true, log: log)
    }

    func identify(accountId: String) async {
        identifiedAccountIds.append(accountId)
        log.record("analytics.identify")
    }

    func capture(_ event: ClientUsageEvent) async {
        captured.append(event)
        log.record("analytics.capture")
    }

    func flushPendingEvents() async {
        flushCount += 1
        log.record("analytics.flush")
        if neverFlushes {
            try? await Task.sleep(for: .seconds(3600))
        }
    }

    func reset() async {
        resetCount += 1
        log.record("analytics.reset")
    }

    private let neverFlushes: Bool
    private let log: CallLog

    private init(neverFlushes: Bool, log: CallLog) {
        self.neverFlushes = neverFlushes
        self.log = log
    }
}
