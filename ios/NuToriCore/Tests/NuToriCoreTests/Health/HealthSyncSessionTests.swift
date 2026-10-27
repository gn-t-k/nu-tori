import Foundation
import NuToriCore
import NuToriTestSupport
import Testing

@Suite("ヘルスケアの見張りの登録")
@MainActor
struct HealthSyncSessionTests {
    @Suite("許可を求め終えているとき")
    @MainActor
    struct AlreadyRequested {
        let starts: Tally
        let session: HealthSyncSession

        init() throws {
            starts = Tally()
            session = try makeSession(requestStatus: .alreadyRequested, starts: starts)
        }

        @Test("起動しただけで、見張りを登録すること")
        func startsOnLaunch() async {
            await session.startDeliveryIfNeeded()

            #expect(starts.count == 1)
        }

        @Suite("起動で登録したあと")
        @MainActor
        struct StartedOnLaunch {
            let starts: Tally
            let session: HealthSyncSession

            init() async throws {
                starts = Tally()
                session = try makeSession(requestStatus: .alreadyRequested, starts: starts)
                await session.startDeliveryIfNeeded()
            }

            @Test("画面を開いても、二重に登録しないこと")
            func doesNotStartTwiceAfterTimelineSync() async {
                await session.aroundTimelineSync {}

                #expect(starts.count == 1)
            }
        }
    }

    @Suite("許可をまだ求めていないとき")
    @MainActor
    struct NotYetRequested {
        let starts: Tally
        let session: HealthSyncSession

        init() throws {
            starts = Tally()
            session = try makeSession(requestStatus: .notYetRequested, starts: starts)
        }

        @Test("起動しただけでは、見張りを登録しないこと")
        func doesNotStartOnLaunch() async {
            await session.startDeliveryIfNeeded()

            #expect(starts.count == 0)
        }
    }
}

@MainActor
private func makeSession(
    requestStatus: HealthAuthorizationRequestStatus, starts: Tally
) throws -> HealthSyncSession {
    let healthStore = HealthStoreMock.ok(requestStatus: requestStatus)
    let session = HealthSyncSession(
        engine: .fixture(healthStore: healthStore, store: try .ok()),
        store: healthStore,
        startBackgroundDelivery: { _ in starts.add() }
    )
    session.bindWakeHandler {}
    return session
}
