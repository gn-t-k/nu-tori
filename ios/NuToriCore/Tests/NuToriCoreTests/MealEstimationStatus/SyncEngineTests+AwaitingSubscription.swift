import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("サブスクリプションを待っている推定の状態を取りに行ったとき")
    struct AwaitingSubscriptionStatuses {
        static let mealId = UUID(uuidString: "00000000-0000-4000-8000-0000000000f1")!
        static let dishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!

        let store: SyncBoxMock<RecordCacheMock>
        let engine: SyncEngine

        init() throws {
            store = try .ok()
            engine = .fixture(
                store: store,
                transport: .sync(pullPages: [
                    """
                    {"changes":[
                      {"sequence":1,"kind":"meal_estimation_status","recordId":"\(Self.mealId.uuidString)",
                       "record":{"mealId":"\(Self.mealId.uuidString)","status":"awaiting_subscription"}},
                      {"sequence":2,"kind":"dish_estimation_status","recordId":"\(Self.dishId.uuidString)",
                       "record":{"dishId":"\(Self.dishId.uuidString)","status":"awaiting_subscription"}}
                    ],"hasMore":false,"nextAfterSequence":2,"startedOn":null}
                    """
                ]))
        }

        @Test("食事と料理ごとの推定の状態を、サブスクリプションを待っているとして読むこと")
        func readsAwaitingSubscription() async throws {
            _ = try await engine.sync()

            #expect(store.cache.estimationStatuses == [Self.mealId: .awaitingSubscription])
            #expect(store.cache.dishEstimationStatuses == [Self.dishId: .awaitingSubscription])
        }
    }
}
