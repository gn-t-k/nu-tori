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

        @Test("画面を送ること")
        func forwardsScreen() async {
            await session.capture(.screen(.weight))

            #expect(forwarding.captured == [.screen(.weight)])
        }
    }

    @Suite("identify の前に開いていた画面")
    struct ScreenBeforeIdentify {
        let forwarding: AnalyticsSessionMock
        let session: GatedAnalyticsSession

        init() {
            forwarding = .ok()
            session = GatedAnalyticsSession(forwarding: forwarding)
        }

        @Test("始めたときに、最後に開いていた画面を1件送ること")
        func sendsTheVisibleScreen() async {
            await session.capture(.screen(.timeline))
            await session.capture(.screen(.weightEntry))

            #expect(forwarding.captured.isEmpty)

            await session.identify(accountId: "account-1")

            #expect(forwarding.captured == [.screen(.weightEntry)])
        }

        @Test("画面以外は、始めても送らないこと")
        func doesNotReplayOtherEvents() async {
            await session.capture(.weightInputCancelled)

            await session.identify(accountId: "account-1")

            #expect(forwarding.captured.isEmpty)
        }

        @Test("reset したあとに始めても、その前の画面は送らないこと")
        func dropsTheScreenAfterReset() async {
            await session.capture(.screen(.timeline))
            await session.reset()

            await session.identify(accountId: "account-1")

            #expect(forwarding.captured.isEmpty)
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
