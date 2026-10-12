import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("食事の推定の状態の同期の形")
struct MealEstimationStatusSyncingTests {
    typealias Status = MealEstimationStatusSyncing.Status

    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = MealEstimationStatusSyncing()
        let cache = MemoryKeyedRecordCache<Status, UUID>(id: \.mealId)
        /// どちらの食事も届いていない
        let keptMealId = UUID()
        let removedMealId = UUID()

        init() throws {
            try syncing.apply(
                [
                    .mealEstimationStatus(.init(mealId: keptMealId, status: .estimating)),
                    .mealEstimationStatus(.init(mealId: removedMealId, status: .awaitingPhotos)),
                ], to: cache)
        }

        @Test("食事が無くても、届いた状態が食事の ID ごとにキャッシュに入ること")
        func storesArrivedStatuses() {
            #expect(
                Set(cache.all()) == [
                    Status(mealId: keptMealId, status: .estimating),
                    Status(mealId: removedMealId, status: .awaitingPhotos),
                ])
        }

        @Test("同じ食事の状態が続けて届いたら、あとに届いた状態にすること")
        func keepsLatestStatus() throws {
            try syncing.apply(
                [
                    .mealEstimationStatus(.init(mealId: keptMealId, status: .deferredToNextDay)),
                    .mealEstimationStatus(.init(mealId: keptMealId, status: .estimated)),
                ], to: cache)

            #expect(
                Set(cache.all()) == [
                    Status(mealId: keptMealId, status: .estimated),
                    Status(mealId: removedMealId, status: .awaitingPhotos),
                ])
        }

        @Test("削除の印の状態が消え、キャッシュに無い状態の削除の印は読み飛ばすこと")
        func removesMarkedStatusesAndSkipsMissing() throws {
            try syncing.apply(
                [
                    .mealEstimationStatusDeletion(mealId: removedMealId),
                    .mealEstimationStatusDeletion(mealId: UUID()),
                ], to: cache)

            #expect(cache.all() == [Status(mealId: keptMealId, status: .estimating)])
        }

        @Test("食事の削除の印は、状態を消さないこと")
        func skipsMealDeletion() throws {
            try syncing.apply([.mealDeletion(mealId: keptMealId)], to: cache)

            #expect(cache.all().count == 2)
        }

        @Test("空にすると、状態がキャッシュから無くなること")
        func erases() throws {
            try syncing.erase(cache)

            #expect(cache.all().isEmpty)
        }
    }
}
