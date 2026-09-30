import NuToriCore
import Testing

@Suite("PostHog を始めるまで送らない")
struct GatedAnalyticsSessionTests {
    let forwarding: AnalyticsSessionMock
    let session: GatedAnalyticsSession

    init() {
        forwarding = .ok()
        session = GatedAnalyticsSession(forwarding: forwarding)
    }

    @Test("identify の前と、reset のあとは出来事を送らないこと")
    func dropsUntilIdentified() async {
        await session.capture(.weightInputCancelled)
        await session.identify(accountId: "account-1")
        await session.capture(.weightInputCancelled)
        await session.reset()
        await session.capture(.screen(.timeline))

        #expect(forwarding.identifiedAccountIds == ["account-1"])
        #expect(forwarding.captured == [.weightInputCancelled])
        #expect(forwarding.resetCount == 1)
    }
}
