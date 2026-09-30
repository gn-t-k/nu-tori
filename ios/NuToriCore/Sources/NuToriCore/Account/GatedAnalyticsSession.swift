public actor GatedAnalyticsSession: AnalyticsSession {
    public init(forwarding: any AnalyticsSession) {
        self.forwarding = forwarding
    }

    public func identify(accountId: String) async {
        identified = true
        await forwarding.identify(accountId: accountId)
    }

    public func capture(_ event: ClientUsageEvent) async {
        guard identified else { return }
        await forwarding.capture(event)
    }

    public func flushPendingEvents() async {
        if Task.isCancelled { return }
        await forwarding.flushPendingEvents()
    }

    public func reset() async {
        identified = false
        await forwarding.reset()
    }

    private let forwarding: any AnalyticsSession
    private var identified = false
}
