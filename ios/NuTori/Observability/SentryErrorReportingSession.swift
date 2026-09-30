import NuToriCore
@preconcurrency import Sentry

actor SentryErrorReportingSession: ErrorReportingSession {
    func identify(accountId: String) async {
        guard !ObservabilityKeys.sentryDSN.isEmpty else { return }
        let shouldStart = !started
        started = true
        await MainActor.run {
            if shouldStart {
                SentrySDK.start { options in
                    options.dsn = ObservabilityKeys.sentryDSN
                    options.environment = "production"
                    options.sendDefaultPii = false
                    options.attachScreenshot = false
                    options.attachViewHierarchy = false
                }
            }
            SentrySDK.setUser(User(userId: accountId))
        }
    }

    func report(_ failure: HandledFailure) async {
        guard started else { return }
        let message =
            switch failure {
            case .sync: "sync"
            case .healthRead: "health_read"
            case .healthWrite: "health_write"
            case .cacheSave: "cache_save"
            }
        await MainActor.run {
            _ = SentrySDK.capture(message: message)
        }
    }

    func clearUser() async {
        guard started else { return }
        started = false
        await MainActor.run {
            SentrySDK.setUser(nil)
            SentrySDK.close()
        }
    }

    private var started = false
}
