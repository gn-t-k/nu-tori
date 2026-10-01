import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

@Suite("送ったあと、推定を待って取りに行く")
struct EstimationFollowUpTests {
    static let mealId = "00000000-0000-4000-8000-0000000000f1"

    static func statusPage(_ status: String, sequence: Int) -> String {
        """
        {"changes":[
          {"sequence":\(sequence),"kind":"meal_estimation_status","recordId":"\(mealId)",
           "record":{"mealId":"\(mealId)","status":"\(status)"}}
        ],"hasMore":false,"nextAfterSequence":\(sequence),"startedOn":null}
        """
    }

    @Suite("推定中の食事が、何回か取りに行くうちに推定できたとき")
    struct EstimatedSoon {
        let clock: WaitingClock
        let transport: ClientTransportMock
        let engine: SyncEngine
        let followUp: EstimationFollowUp

        init() async throws {
            clock = WaitingClock(start: SyncEngine.fixtureNow)
            let store = try SyncBoxMock.ok()
            transport = .sync(pullPages: [
                EstimationFollowUpTests.statusPage("estimating", sequence: 1),
                EstimationFollowUpTests.statusPage("estimating", sequence: 2),
                EstimationFollowUpTests.statusPage("estimated", sequence: 3),
            ])
            engine = .fixture(store: store, transport: transport)
            _ = try await engine.sync()
            followUp = EstimationFollowUp(
                sentAt: SyncEngine.fixtureNow, cache: store, now: clock.now, wait: clock.wait)
        }

        @Test("数秒おきに取りに行き、推定中の食事が無くなったらやめること")
        func pollsUntilEstimated() async throws {
            try await followUp.run { try await engine.sync() }

            #expect(try transport.pullQueries.count == 3)
            #expect(clock.waits == [.seconds(3), .seconds(3)])
        }
    }

    @Suite("推定中のまま、送ってから1分たったとき")
    struct StillEstimatingAfterAMinute {
        let clock: WaitingClock
        let transport: ClientTransportMock
        let engine: SyncEngine
        let followUp: EstimationFollowUp

        init() async throws {
            clock = WaitingClock(start: SyncEngine.fixtureNow)
            let store = try SyncBoxMock.ok()
            transport = .sync(pullPages: [
                EstimationFollowUpTests.statusPage("estimating", sequence: 1)
            ])
            engine = .fixture(store: store, transport: transport)
            _ = try await engine.sync()
            followUp = EstimationFollowUp(
                sentAt: SyncEngine.fixtureNow, cache: store, now: clock.now, wait: clock.wait)
        }

        @Test("送ってから1分で取りに行くのをやめ、ふだんの時機に任せること")
        func stopsAfterAMinute() async throws {
            try await followUp.run { try await engine.sync() }

            #expect(clock.waits.count == 20)
            #expect(try transport.pullQueries.count == 21)
        }
    }

    @Suite("翌日に推定の食事だけがあるとき")
    struct DeferredOnly {
        let clock: WaitingClock
        let transport: ClientTransportMock
        let followUp: EstimationFollowUp

        init() async throws {
            clock = WaitingClock(start: SyncEngine.fixtureNow)
            let store = try SyncBoxMock.ok()
            transport = .sync(pullPages: [
                EstimationFollowUpTests.statusPage("deferred_to_next_day", sequence: 1)
            ])
            let engine = SyncEngine.fixture(store: store, transport: transport)
            _ = try await engine.sync()
            followUp = EstimationFollowUp(
                sentAt: SyncEngine.fixtureNow, cache: store, now: clock.now, wait: clock.wait)
        }

        @Test("待たずに、取りに行かないこと")
        func doesNotPoll() async throws {
            try await followUp.run {
                Issue.record("取りに行った")
                return nil
            }

            #expect(clock.waits.isEmpty)
        }
    }

    @Suite("取りに行く途中で、回数の歯止めにかかったとき")
    struct RateLimited {
        let clock: WaitingClock
        let followUp: EstimationFollowUp

        init() async throws {
            clock = WaitingClock(start: SyncEngine.fixtureNow)
            let store = try SyncBoxMock.ok()
            let engine = SyncEngine.fixture(
                store: store,
                transport: .sync(pullPages: [
                    EstimationFollowUpTests.statusPage("estimating", sequence: 1)
                ]))
            _ = try await engine.sync()
            followUp = EstimationFollowUp(
                sentAt: SyncEngine.fixtureNow, cache: store, now: clock.now, wait: clock.wait)
        }

        @Test("続けずにやめること")
        func stopsWhenSyncStopped() async throws {
            var syncCount = 0

            try await followUp.run {
                syncCount += 1
                return SyncResult(rejectedWrites: [], ending: .stopped(.rateLimited))
            }

            #expect(syncCount == 1)
        }
    }
}
