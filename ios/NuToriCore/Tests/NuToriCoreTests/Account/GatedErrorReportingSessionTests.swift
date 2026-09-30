import NuToriCore
import Testing

@Suite("Sentry を始めるまで送らない")
struct GatedErrorReportingSessionTests {
    @Suite("identify の前")
    struct BeforeIdentify {
        let forwarding: ErrorReportingSessionMock
        let session: GatedErrorReportingSession

        init() {
            forwarding = .ok()
            session = GatedErrorReportingSession(forwarding: forwarding)
        }

        @Test("失敗を送らないこと")
        func drops() async {
            await session.report(.sync)

            #expect(forwarding.reported.isEmpty)
        }
    }

    @Suite("identify のあと")
    struct AfterIdentify {
        let forwarding: ErrorReportingSessionMock
        let session: GatedErrorReportingSession

        init() async {
            forwarding = .ok()
            session = GatedErrorReportingSession(forwarding: forwarding)
            await session.identify(accountId: "account-1")
        }

        @Test("失敗を送ること")
        func forwards() async {
            await session.report(.healthWrite)

            #expect(forwarding.identifiedAccountIds == ["account-1"])
            #expect(forwarding.reported == [.healthWrite])
        }
    }

    @Suite("user を外したあと")
    struct AfterClearUser {
        let forwarding: ErrorReportingSessionMock
        let session: GatedErrorReportingSession

        init() async {
            forwarding = .ok()
            session = GatedErrorReportingSession(forwarding: forwarding)
            await session.identify(accountId: "account-1")
            await session.clearUser()
        }

        @Test("失敗を送らないこと")
        func drops() async {
            await session.report(.cacheSave)

            #expect(forwarding.clearUserCount == 1)
            #expect(forwarding.reported.isEmpty)
        }
    }
}
