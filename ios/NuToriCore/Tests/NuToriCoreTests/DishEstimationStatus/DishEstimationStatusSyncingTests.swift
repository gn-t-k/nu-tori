import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("料理ごとの推定の状態の同期の形")
struct DishEstimationStatusSyncingTests {
    typealias Status = DishEstimationStatusSyncing.Status

    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = DishEstimationStatusSyncing()
        let cache = MemoryKeyedRecordCache<Status, UUID>(id: \.dishId)
        /// どちらの料理も届いていない
        let keptDishId = UUID()
        let removedDishId = UUID()

        init() throws {
            try syncing.apply(
                [
                    .dishEstimationStatus(.init(dishId: keptDishId, status: .estimating)),
                    .dishEstimationStatus(.init(dishId: removedDishId, status: .failed)),
                ], to: cache)
        }

        @Test("料理が無くても、届いた状態が料理の ID ごとにキャッシュに入ること")
        func storesArrivedStatuses() {
            #expect(
                Set(cache.all()) == [
                    Status(dishId: keptDishId, status: .estimating),
                    Status(dishId: removedDishId, status: .failed),
                ])
        }

        @Test("同じ料理の状態が続けて届いたら、あとに届いた状態にすること")
        func keepsLatestStatus() throws {
            try syncing.apply(
                [
                    .dishEstimationStatus(.init(dishId: keptDishId, status: .deferredToNextDay)),
                    .dishEstimationStatus(.init(dishId: keptDishId, status: .estimated)),
                ], to: cache)

            #expect(
                Set(cache.all()) == [
                    Status(dishId: keptDishId, status: .estimated),
                    Status(dishId: removedDishId, status: .failed),
                ])
        }

        @Test("削除の印の状態が消え、キャッシュに無い状態の削除の印は読み飛ばすこと")
        func removesMarkedStatusesAndSkipsMissing() throws {
            try syncing.apply(
                [
                    .dishEstimationStatusDeletion(dishId: removedDishId),
                    .dishEstimationStatusDeletion(dishId: UUID()),
                ], to: cache)

            #expect(cache.all() == [Status(dishId: keptDishId, status: .estimating)])
        }

        @Test("料理の削除の印は、状態を消さないこと")
        func skipsDishDeletion() throws {
            try syncing.apply([.dishDeletion(dishId: keptDishId)], to: cache)

            #expect(cache.all().count == 2)
        }

        @Test("空にすると、状態がキャッシュから無くなること")
        func erases() throws {
            try syncing.erase(cache)

            #expect(cache.all().isEmpty)
        }
    }
}
