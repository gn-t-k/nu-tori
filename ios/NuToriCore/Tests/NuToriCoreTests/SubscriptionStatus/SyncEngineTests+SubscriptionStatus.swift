import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("サブスクリプションの状態の同期")
    struct SubscriptionStatusKind {
        static let recordId = "00000000-0000-4000-8000-0000000000f1"

        @Suite("サブスクリプションの状態を取りに行ったとき")
        struct Pulling {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() throws {
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          {"sequence":1,"kind":"subscription_status","recordId":"\(SubscriptionStatusKind.recordId)",
                           "record":{"type":"regular","freeTrial":{"type":"available","lastDay":"2026-11-19"},
                                     "subscription":{"type":"none"}}},
                          {"sequence":2,"kind":"subscription_status","recordId":"\(SubscriptionStatusKind.recordId)",
                           "record":{"type":"regular","freeTrial":{"type":"available","lastDay":"2026-11-19"},
                                     "subscription":{"type":"subscribed","plan":"monthly",
                                                     "periodEndsAt":"2026-12-01T03:04:05.678Z",
                                                     "billingGrace":{"type":"granted","endsAt":"2026-12-17T00:00:00.000Z"}}}}
                        ],"hasMore":false,"nextAfterSequence":2,"startedOn":null}
                        """
                    ]))
            }

            @Test("最後に届いた状態が、日付と時刻を読んでキャッシュに入ること")
            func storesLatest() async throws {
                let result = try await engine.sync()

                #expect(result.ending == .finished)
                #expect(
                    store.cache.subscriptionStatus
                        == .regular(
                            freeTrial: .available(
                                lastDay: CalendarDay(year: 2026, month: 11, day: 19)),
                            subscription: .subscribed(
                                plan: .monthly,
                                periodEndsAt: Date(timeIntervalSince1970: 1_796_094_245.678),
                                billingGrace: .granted(
                                    endsAt: Date(timeIntervalSince1970: 1_797_465_600)))))
            }
        }

        @Suite("知らない形のサブスクリプションの状態が届いたとき")
        struct PullingUnknownShape {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() throws {
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          {"sequence":1,"kind":"subscription_status","recordId":"\(SubscriptionStatusKind.recordId)",
                           "record":{"type":"test_user"}},
                          {"sequence":2,"kind":"subscription_status","recordId":"\(SubscriptionStatusKind.recordId)",
                           "record":{"type":"regular","freeTrial":{"type":"available","lastDay":"2026-11-19"},
                                     "subscription":{"type":"subscribed","plan":"weekly",
                                                     "periodEndsAt":"2026-12-01T00:00:00.000Z",
                                                     "billingGrace":{"type":"none"}}}}
                        ],"hasMore":false,"nextAfterSequence":2,"startedOn":null}
                        """
                    ]))
            }

            @Test("同期を止めず、読めた前の状態のままにすること")
            func keepsReadableStatus() async throws {
                let result = try await engine.sync()

                #expect(result.ending == .finished)
                #expect(store.cache.subscriptionStatus == .testUser)
            }
        }

        @Suite("読める種類にサブスクリプションの状態が増えた版で、更新して最初に開いたとき")
        struct AfterUpdateAddingSubscriptionStatus {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() throws {
                let readableKinds = RecordKindRegistry<RecordCacheMock>.ok().names
                store = try .ok(
                    state: .fixture(
                        afterSequence: 120, hasCompletedInitialPull: true,
                        readableKinds: readableKinds.subtracting([.subscriptionStatus])))
                transport = .sync()
                engine = .fixture(
                    store: store, transport: transport, readableKinds: readableKinds)
            }

            @Test("通し番号を 0 に戻して全部取り直し、読める種類にサブスクリプションの状態を足すこと")
            func pullsEverythingAgain() async throws {
                _ = try await engine.sync()

                #expect(try transport.pullQueries.first?["afterSequence"] == "0")
                #expect(store.state?.readableKinds.contains(.subscriptionStatus) == true)
            }
        }
    }
}
