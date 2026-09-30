import NuToriCore
import Testing

@Suite("PostHog を始めるまで送らない")
struct GatedAnalyticsSessionTests {
    @Suite("identify の前")
    struct BeforeIdentify {
        let forwarding: AnalyticsSessionMock
        let session: GatedAnalyticsSession

        init() {
            forwarding = .ok()
            session = GatedAnalyticsSession(forwarding: forwarding)
        }

        @Test("出来事を送らないこと")
        func drops() async {
            await session.capture(.weightInputCancelled)

            #expect(forwarding.captured.isEmpty)
        }
    }

    @Suite("identify のあと")
    struct AfterIdentify {
        let forwarding: AnalyticsSessionMock
        let session: GatedAnalyticsSession

        init() async {
            forwarding = .ok()
            session = GatedAnalyticsSession(forwarding: forwarding)
            await session.identify(accountId: "account-1")
        }

        @Test("出来事を送ること")
        func forwards() async {
            await session.capture(.weightInputCancelled)

            #expect(forwarding.identifiedAccountIds == ["account-1"])
            #expect(forwarding.captured == [.weightInputCancelled])
        }
    }

    @Suite("reset のあと")
    struct AfterReset {
        let forwarding: AnalyticsSessionMock
        let session: GatedAnalyticsSession

        init() async {
            forwarding = .ok()
            session = GatedAnalyticsSession(forwarding: forwarding)
            await session.identify(accountId: "account-1")
            await session.reset()
        }

        @Test("出来事を送らないこと")
        func drops() async {
            await session.capture(.screen(.timeline))

            #expect(forwarding.resetCount == 1)
            #expect(forwarding.captured.isEmpty)
        }
    }
}
