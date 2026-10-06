public actor GatedErrorReportingSession: ErrorReportingSession {
    public init(forwarding: any ErrorReportingSession) {
        self.forwarding = forwarding
    }

    public func identify(accountId: String) async {
        identified = true
        await forwarding.identify(accountId: accountId)
    }

    public func report(_ failure: HandledFailure, cause: FailureCause?) async {
        guard identified else { return }
        await forwarding.report(failure, cause: cause)
    }

    public func clearUser() async {
        identified = false
        await forwarding.clearUser()
    }

    private let forwarding: any ErrorReportingSession
    private var identified = false
}
