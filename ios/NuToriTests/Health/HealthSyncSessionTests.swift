import Foundation
import NuToriCore
import Synchronization
import Testing

@testable import NuTori

@Suite("ヘルスケアの見張りの登録")
@MainActor
struct HealthSyncSessionTests {
    @Suite("許可を求め終えているとき")
    @MainActor
    struct AlreadyRequested {
        fileprivate let starts = DeliveryStarts()
        let session: HealthSyncSession

        init() throws {
            session = try makeSession(authorization: .alreadyRequested, starts: starts)
        }

        @Test("起動しただけで、見張りを登録すること")
        func startsOnLaunch() async {
            await session.startDeliveryIfNeeded()

            #expect(starts.count == 1)
        }

        @Suite("起動で登録したあと")
        @MainActor
        struct StartedOnLaunch {
            fileprivate let starts = DeliveryStarts()
            let session: HealthSyncSession

            init() async throws {
                session = try makeSession(authorization: .alreadyRequested, starts: starts)
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
        fileprivate let starts = DeliveryStarts()
        let session: HealthSyncSession

        init() throws {
            session = try makeSession(authorization: .notYetRequested, starts: starts)
        }

        @Test("起動しただけでは、見張りを登録しないこと")
        func doesNotStartOnLaunch() async {
            await session.startDeliveryIfNeeded()

            #expect(starts.count == 0)
        }
    }
}

/// 見張りを登録した回数
private final class DeliveryStarts: Sendable {
    var count: Int { value.withLock { $0 } }

    func record() {
        value.withLock { $0 += 1 }
    }

    private let value = Mutex(0)
}

@MainActor
private func makeSession(
    authorization: UITestHealthStore.Authorization, starts: DeliveryStarts
) throws -> HealthSyncSession {
    let session = HealthSyncSession.live(
        syncStore: try SwiftDataSyncStore(inMemory: true),
        healthStore: UITestHealthStore(
            authorization: authorization, latestKilograms: nil, writeAuthorized: true,
            clock: .live),
        errorReporting: PlaceholderErrorReportingSession(),
        startBackgroundDelivery: { _ in starts.record() },
        clock: .live
    )
    session.bindWakeHandler {}
    return session
}
