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

    func report(_ failure: HandledFailure, cause: FailureCause?) async {
        guard started else { return }
        let name = failure.reportName
        await MainActor.run {
            _ = SentrySDK.capture(message: name) { scope in
                // スタックはどの種類でも同じで、Sentry がスタックで分けると種類を問わず1つの課題にまとまるので、種類で分ける。
                // 原因のコードは入れない。同じ種類の失敗がコードごとに課題に割れないようにするため
                scope.setFingerprint(["handled-failure", name])
                guard let cause else { return }
                scope.setTag(value: cause.domain, key: "error.domain")
                scope.setTag(value: String(cause.code), key: "error.code")
            }
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
