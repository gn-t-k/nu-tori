import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("食事の同期の形")
struct MealSyncingTests {
    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = MealSyncing()
        let cache: MemoryKeyedRecordCache<Meal, UUID>
        let kept: Meal
        let removed: Meal

        init() throws {
            (cache, kept, removed) = try Self.appliedCache()
        }

        /// 食事を2件当てたキャッシュ
        static func appliedCache() throws -> (
            cache: MemoryKeyedRecordCache<Meal, UUID>, kept: Meal, removed: Meal
        ) {
            let cache = MemoryKeyedRecordCache<Meal, UUID>(id: \.id)
            let kept = try Meal.fixture(
                eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:15:00+09:00")
            let removed = try Meal.fixture(
                eatenAt: "2026-09-24T19:30:00+09:00", sentAt: "2026-09-24T19:40:00+09:00")
            try MealSyncing().apply([kept, removed].map { .meal(synced($0)) }, to: cache)
            return (cache, kept, removed)
        }

        static func synced(_ meal: Meal, eatenAt: Date? = nil) -> SyncedMeal {
            SyncedMeal(
                id: meal.id, eatenAt: eatenAt ?? meal.eatenAt,
                eatenUtcOffsetSeconds: meal.eatenUtcOffsetSeconds, sentAt: meal.sentAt,
                sentTimeZone: meal.sentTimeZone, entryMethod: .picked, photoIds: meal.photoIds)
        }

        @Test("届いた食事が今の値でキャッシュに入ること")
        func storesArrivedMeals() {
            #expect(Set(cache.all()) == [kept, removed])
        }

        @Suite("同じ食事が、食べた時刻を直して届き直したとき")
        struct ArrivedAgain {
            let syncing = MealSyncing()
            let cache: MemoryKeyedRecordCache<Meal, UUID>
            let kept: Meal
            let corrected: Date

            init() throws {
                let applied = try Applying.appliedCache()
                cache = applied.cache
                kept = applied.kept
                corrected = applied.kept.eatenAt.addingTimeInterval(-3600)
            }

            @Test("キャッシュの食事をその値にそろえること")
            func overwritesWithArrivedValue() throws {
                try syncing.apply([.meal(Applying.synced(kept, eatenAt: corrected))], to: cache)

                #expect(cache.all().first { $0.id == kept.id }?.eatenAt == corrected)
                #expect(cache.all().count == 2)
            }
        }

        @Test("削除の印の食事が消え、キャッシュに無い食事の削除の印は読み飛ばすこと")
        func removesMarkedMealsAndSkipsMissing() throws {
            try syncing.apply(
                [.mealDeletion(mealId: removed.id), .mealDeletion(mealId: UUID())], to: cache)

            #expect(cache.all() == [kept])
        }

        @Test("同じ食事の今の値と削除の印が一緒に届いたら、消えていること")
        func removalWinsOverValueInSameChanges() throws {
            try syncing.apply(
                [.mealDeletion(mealId: kept.id), .meal(Self.synced(kept))], to: cache)

            #expect(cache.all() == [removed])
        }

        @Test("ほかの種類の変更は、キャッシュを変えないこと")
        func skipsOtherKinds() throws {
            try syncing.apply([.mealEstimationStatusDeletion(mealId: kept.id)], to: cache)

            #expect(cache.all().count == 2)
        }

        @Test("空にすると、食事がキャッシュから無くなること")
        func erases() throws {
            try syncing.erase(cache)

            #expect(cache.all().isEmpty)
        }
    }
}
