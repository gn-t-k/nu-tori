import Foundation
import NuToriAPI
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("食事と推定の状態の種類")
struct MealRecordKindTests {
    static func syncedMeal(id: UUID) -> SyncedMeal {
        SyncedMeal(
            id: id,
            eatenAt: Date(timeIntervalSince1970: 1_790_046_600),
            eatenUtcOffsetSeconds: 32_400,
            sentAt: Date(timeIntervalSince1970: 1_790_046_660),
            sentTimeZone: TimeZone(identifier: "Asia/Tokyo")!,
            entryMethod: .picked,
            photoIds: [
                UUID(uuidString: "00000000-0000-4000-8000-0000000000c2")!,
                UUID(uuidString: "00000000-0000-4000-8000-0000000000c1")!,
            ]
        )
    }

    @Suite("取りに行った食事と推定の状態をキャッシュに当てるとき")
    @MainActor
    struct Applying {
        let store: SwiftDataSyncStore
        let kept: UUID
        let removed: UUID

        init() async throws {
            store = try SwiftDataSyncStore(inMemory: true)
            kept = UUID(uuidString: "00000000-0000-4000-8000-0000000000f1")!
            removed = UUID(uuidString: "00000000-0000-4000-8000-0000000000f2")!
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(
                        kind: .meal,
                        changes: [
                            .meal(MealRecordKindTests.syncedMeal(id: kept)),
                            .meal(MealRecordKindTests.syncedMeal(id: removed)),
                        ]),
                    KindChanges(
                        kind: .mealEstimationStatus,
                        changes: [
                            .mealEstimationStatus(.init(mealId: kept, status: .awaitingPhotos)),
                            .mealEstimationStatus(.init(mealId: removed, status: .failed)),
                        ]),
                ]))
        }

        @Test("届いた食事が、写真の並び順を保ってキャッシュに入ること")
        func storesMeals() throws {
            let meals = try store.container.mainContext.fetch(FetchDescriptor<CachedMeal>())
                .compactMap { $0.meal() }

            #expect(Set(meals.map(\.id)) == [kept, removed])
            #expect(
                meals.first { $0.id == kept }?.photoIds
                    == MealRecordKindTests.syncedMeal(id: kept).photoIds)
        }

        @Test("新しい推定の状態が、前の状態を上書きすること")
        func overwritesStatus() async throws {
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(
                        kind: .mealEstimationStatus,
                        changes: [.mealEstimationStatus(.init(mealId: kept, status: .estimating))])
                ]))

            #expect(
                try await store.mealEstimationStatuses() == [kept: .estimating, removed: .failed])
        }

        @Test("削除の印の食事と推定の状態が消えること")
        func removesDeleted() async throws {
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(kind: .meal, changes: [.mealDeletion(mealId: removed)]),
                    KindChanges(
                        kind: .mealEstimationStatus,
                        changes: [.mealEstimationStatusDeletion(mealId: removed)]),
                ]))

            let meals = try store.container.mainContext.fetch(FetchDescriptor<CachedMeal>())
            #expect(meals.map(\.mealId) == [kept])
            #expect(try await store.mealEstimationStatuses() == [kept: .awaitingPhotos])
        }

        @Test("全消去で、食事と推定の状態がキャッシュから無くなること")
        func erasesWithEverythingElse() async throws {
            try await store.eraseAll()

            #expect(try store.container.mainContext.fetch(FetchDescriptor<CachedMeal>()).isEmpty)
            #expect(try await store.mealEstimationStatuses().isEmpty)
        }
    }
}
