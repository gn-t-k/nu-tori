public actor GatedAnalyticsSession: AnalyticsSession {
    public init(forwarding: any AnalyticsSession) {
        self.forwarding = forwarding
    }

    public func identify(accountId: String) async {
        identified = true
        await forwarding.identify(accountId: accountId)
        if let pendingScreen {
            self.pendingScreen = nil
            await forwarding.capture(pendingScreen)
        }
    }

    public func capture(_ event: ClientUsageEvent) async {
        if case .screen = event {
            // 始まる前から開いている画面は、始めたときに1件送る
            guard identified else {
                pendingScreen = event
                return
            }
            await forwarding.capture(event)
            return
        }
        guard identified else { return }
        await forwarding.capture(event)
    }

    public func flushPendingEvents() async {
        if Task.isCancelled { return }
        await forwarding.flushPendingEvents()
    }

    public func reset() async {
        identified = false
        pendingScreen = nil
        await forwarding.reset()
    }

    private let forwarding: any AnalyticsSession
    private var identified = false
    /// 始める前に見えていた画面。始まってから開いた画面は、その場で送る
    private var pendingScreen: ClientUsageEvent?
}
