import NuToriCore
import PostHog

actor PostHogAnalyticsSession: AnalyticsSession {
    func identify(accountId: String) async {
        if !didStart {
            didStart = true
            await MainActor.run {
                let config = PostHogConfig(
                    projectToken: ObservabilityKeys.postHogAPIKey,
                    host: ObservabilityKeys.postHogHost)
                config.captureScreenViews = false
                config.sessionReplay = false
                config.errorTrackingConfig.autoCapture = false
                PostHogSDK.shared.setup(config)
            }
        }
        await MainActor.run {
            PostHogSDK.shared.optIn()
            PostHogSDK.shared.identify(accountId)
        }
    }

    func capture(_ event: ClientUsageEvent) async {
        let fields = event.fields
        let name = event.name
        let screen = event.screenToken
        await MainActor.run {
            guard !PostHogSDK.shared.isOptOut() else { return }
            if let screen {
                PostHogSDK.shared.screen(screen)
                return
            }
            PostHogSDK.shared.capture(name, properties: Self.values(fields))
        }
    }

    func flushPendingEvents() async {
        await CancellableFlush.run {
            await MainActor.run {
                PostHogSDK.shared.flush()
            }
        }
    }

    func reset() async {
        await MainActor.run {
            guard !PostHogSDK.shared.isOptOut() else { return }
            // reset はオプトアウトも消す。サインインし直すまで送らないよう、そのあと止める
            PostHogSDK.shared.reset()
            PostHogSDK.shared.optOut()
        }
    }

    private var didStart = false

    private static func values(_ fields: [String: ClientUsageEvent.Field]) -> [String: Any] {
        var values: [String: Any] = [:]
        for (key, field) in fields {
            switch field {
            case .count(let count): values[key] = count
            case .wholeSeconds(let seconds): values[key] = seconds
            case .flag(let flag): values[key] = flag
            case .token(let token): values[key] = token
            }
        }
        return values
    }
}
