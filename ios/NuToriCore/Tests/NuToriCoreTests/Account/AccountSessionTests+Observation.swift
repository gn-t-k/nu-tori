import Foundation
import NuToriCore
import Testing

extension AccountSessionTests {
    @Suite("観測を始める")
    struct StartingObservation {
        @Suite("サインイン済みで、初回の取得を終え、利用状況がオンのとき")
        struct ReadyToSend {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn()
                session = device.session()
            }

            @Test("Sentry と PostHog の両方を、アカウント ID で始めること")
            func identifiesBoth() async {
                await session.beginObservationIfSignedIn()

                #expect(device.errorReporting.identifiedAccountIds == ["account-1"])
                #expect(device.analytics.identifiedAccountIds == ["account-1"])
            }

            @Test("初回の取得にかかった時間を、PostHog を始めたあとに送ること")
            func sendsInitialPullDuration() async throws {
                let started = Date(timeIntervalSince1970: 1_700_000_000)
                await session.noteInitialPull(
                    beforeComplete: false,
                    afterComplete: true,
                    finished: true,
                    startedAt: started,
                    now: started.addingTimeInterval(12)
                )

                #expect(device.analytics.identifiedAccountIds == ["account-1"])
                #expect(device.analytics.captured == [.initialPullDuration(.seconds(12))])
                let events = device.log.events
                let identify = try #require(events.firstIndex(of: "analytics.identify"))
                let capture = try #require(events.firstIndex(of: "analytics.capture"))
                #expect(identify < capture)
            }
        }

        @Suite("初回の取得を終えていないとき")
        struct BeforeInitialPull {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn(hasCompletedInitialPull: false)
                session = device.session()
            }

            @Test("Sentry だけを始め、初回の取得の時間は送らないこと")
            func startsSentryOnly() async {
                await session.beginObservationIfSignedIn()
                await session.noteInitialPull(
                    beforeComplete: false,
                    afterComplete: false,
                    finished: true,
                    startedAt: .now,
                    now: .now
                )

                #expect(device.errorReporting.identifiedAccountIds == ["account-1"])
                #expect(device.analytics.identifiedAccountIds.isEmpty)
                #expect(device.analytics.captured.isEmpty)
            }
        }

        @Suite("利用状況がオフのとき")
        struct UsageDataOff {
            let device: AccountDevice
            let session: AccountSession

            init() async throws {
                device = try .signedIn()
                session = device.session()
                let settings = AccountSettings.fixture(sendsUsageData: false)
                try await device.syncStore.save(
                    settings,
                    enqueuing: PendingWrite(
                        writeId: UUID(),
                        enqueuedAt: .now,
                        operation: .updateAccountSettings(settings)
                    )
                )
            }

            @Test("PostHog を始めず、初回の取得の時間も送らないこと")
            func doesNotStartPostHog() async throws {
                await session.noteInitialPull(
                    beforeComplete: false,
                    afterComplete: true,
                    finished: true,
                    startedAt: .now,
                    now: .now
                )

                #expect(device.errorReporting.identifiedAccountIds == ["account-1"])
                #expect(device.analytics.identifiedAccountIds.isEmpty)
                #expect(device.analytics.captured.isEmpty)
            }
        }

        @Suite("サインインの画面を出しているとき")
        struct SignInAgain {
            let device: AccountDevice
            let session: AccountSession

            init() async throws {
                device = try .signedIn()
                session = device.session()
                try await device.deviceStore.setSignInAgainMark()
            }

            @Test("サインインし直すまで、Sentry も PostHog も始めないこと")
            func doesNotStart() async {
                await session.beginObservationIfSignedIn()

                #expect(device.errorReporting.identifiedAccountIds.isEmpty)
                #expect(device.analytics.identifiedAccountIds.isEmpty)
            }
        }

        @Suite("利用状況をオフにするとき")
        struct TurningOff {
            let device: AccountDevice
            let session: AccountSession

            init() throws {
                device = try .signedIn()
                session = device.session()
            }

            @Test("オフが効く前に1件送ってから、PostHog を止めること")
            func sendsOneEventThenResets() async throws {
                await session.turnOffUsageData()

                #expect(device.analytics.captured == [.usageDataTurnedOff])
                #expect(device.analytics.resetCount == 1)
                let events = device.log.events
                let capture = try #require(events.firstIndex(of: "analytics.capture"))
                let reset = try #require(events.firstIndex(of: "analytics.reset"))
                #expect(capture < reset)
            }
        }
    }
}
