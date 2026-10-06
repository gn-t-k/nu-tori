import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("料理ごとの推定の状態の同期")
    struct DishEstimationStatusKind {
        static let dishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!
        static let removedDishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d2")!

        @Suite("料理が届く前に、料理ごとの推定の状態を取りに行ったとき")
        struct PullingBeforeDish {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() throws {
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          {"sequence":1,"kind":"dish_estimation_status","recordId":"\(DishEstimationStatusKind.dishId.uuidString)",
                           "record":{"dishId":"\(DishEstimationStatusKind.dishId.uuidString)","status":"estimating"}},
                          {"sequence":2,"kind":"dish_estimation_status","recordId":"\(DishEstimationStatusKind.removedDishId.uuidString)",
                           "record":{"dishId":"\(DishEstimationStatusKind.removedDishId.uuidString)","status":"failed"}},
                          {"sequence":3,"kind":"dish_estimation_status","recordId":"\(DishEstimationStatusKind.dishId.uuidString)",
                           "record":{"dishId":"\(DishEstimationStatusKind.dishId.uuidString)","status":"deferred_to_next_day"}},
                          {"sequence":4,"kind":"dish_estimation_status_deletion","recordId":"\(DishEstimationStatusKind.removedDishId.uuidString)","record":{}}
                        ],"hasMore":false,"nextAfterSequence":4,"startedOn":null}
                        """
                    ]))
            }

            @Test("料理が無くても、いちばんあとに届いた状態をキャッシュに当てること")
            func appliesLatestStatusWithoutDish() async throws {
                _ = try await engine.sync()

                #expect(store.cache.dishes.isEmpty)
                #expect(
                    store.cache.dishEstimationStatuses[DishEstimationStatusKind.dishId]
                        == .deferredToNextDay)
            }

            @Test("削除の印の料理の状態をキャッシュから消すこと")
            func removesDeleted() async throws {
                _ = try await engine.sync()

                #expect(
                    store.cache.dishEstimationStatuses[DishEstimationStatusKind.removedDishId]
                        == nil)
            }
        }

        @Suite("知らない料理ごとの推定の状態が届いたとき")
        struct PullingUnknownStatus {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() throws {
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          {"sequence":1,"kind":"dish_estimation_status","recordId":"\(DishEstimationStatusKind.dishId.uuidString)",
                           "record":{"dishId":"\(DishEstimationStatusKind.dishId.uuidString)","status":"future_status"}}
                        ],"hasMore":false,"nextAfterSequence":1,"startedOn":null}
                        """
                    ]))
            }

            @Test("同期を止めずに読み飛ばすこと")
            func skipsUnknownStatus() async throws {
                let result = try await engine.sync()

                #expect(result.ending == .finished)
                #expect(store.cache.dishEstimationStatuses.isEmpty)
            }
        }

        @Suite("読める種類に料理ごとの推定の状態が増えた版で、更新して最初に開いたとき")
        struct AfterUpdateAddingDishEstimationStatus {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() throws {
                let readableKinds = RecordKindRegistry<RecordCacheMock>.ok().names
                store = try .ok(
                    state: .fixture(
                        afterSequence: 120, hasCompletedInitialPull: true,
                        readableKinds: readableKinds.subtracting([.dishEstimationStatus])))
                transport = .sync()
                engine = .fixture(
                    store: store, transport: transport, readableKinds: readableKinds)
            }

            @Test("通し番号を 0 に戻して全部取り直し、読める種類に料理ごとの推定の状態を足すこと")
            func pullsEverythingAgain() async throws {
                _ = try await engine.sync()

                #expect(try transport.pullQueries.first?["afterSequence"] == "0")
                #expect(store.state?.readableKinds.contains(.dishEstimationStatus) == true)
            }
        }

        @Suite("料理ごとの推定の状態の種類の送り待ちがあるとき")
        struct PendingStatus {
            let engine: SyncEngine

            init() throws {
                engine = .fixture(
                    store: try .ok(pendingEntries: [
                        PendingEntry(
                            writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                            kind: .dishEstimationStatus, content: Data())
                    ]),
                    transport: .sync())
            }

            @Test("サーバーだけが書く種類として、送らずに投げること")
            func throwsServerOnly() async throws {
                await #expect(throws: UnknownRecordKindError.serverOnly(.dishEstimationStatus)) {
                    _ = try await engine.sync()
                }
            }
        }
    }
}
