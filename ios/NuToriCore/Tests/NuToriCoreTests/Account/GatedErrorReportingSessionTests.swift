import NuToriCore
import Testing

@Suite("Sentry を始めるまで送らない")
struct GatedErrorReportingSessionTests {
    let forwarding: ErrorReportingSessionMock
    let session: GatedErrorReportingSession

    init() {
        forwarding = .ok()
        session = GatedErrorReportingSession(forwarding: forwarding)
    }

    @Test("identify の前と、user を外したあとは失敗を送らないこと")
    func dropsUntilIdentified() async {
        await session.report(.sync)
        await session.identify(accountId: "account-1")
        await session.report(.healthWrite)
        await session.clearUser()
        await session.report(.cacheSave)

        #expect(forwarding.identifiedAccountIds == ["account-1"])
        #expect(forwarding.reported == [.healthWrite])
        #expect(forwarding.clearUserCount == 1)
    }
}
