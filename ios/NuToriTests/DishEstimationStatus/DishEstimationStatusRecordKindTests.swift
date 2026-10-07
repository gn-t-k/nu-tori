import Foundation
import NuToriAPI
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("料理ごとの推定の状態の種類")
struct DishEstimationStatusRecordKindTests {
    static let keptDishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!
    static let removedDishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d2")!

    @Suite("料理より先に、取りに行った状態をキャッシュに当てるとき")
    @MainActor
    struct Applying {
        let store: SwiftDataSyncStore

        init() async throws {
            store = try SwiftDataSyncStore(inMemory: true)
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(
                        kind: .dishEstimationStatus,
                        changes: [
                            .dishEstimationStatus(
                                .init(
                                    dishId: DishEstimationStatusRecordKindTests.keptDishId,
                                    status: .estimating)),
                            .dishEstimationStatus(
                                .init(
                                    dishId: DishEstimationStatusRecordKindTests.removedDishId,
                                    status: .failed)),
                            .dishEstimationStatus(
                                .init(
                                    dishId: DishEstimationStatusRecordKindTests.keptDishId,
                                    status: .deferredToNextDay)),
                        ])
                ]))
        }

        @Test("料理が無くても、いちばんあとに届いた状態がキャッシュに入ること")
        func storesLatestStatus() async throws {
            #expect(
                try await store.dishEstimationStatuses() == [
                    DishEstimationStatusRecordKindTests.keptDishId: .deferredToNextDay,
                    DishEstimationStatusRecordKindTests.removedDishId: .failed,
                ])
        }

        @Test("削除の印の料理の状態が消えること")
        func removesDeleted() async throws {
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(
                        kind: .dishEstimationStatus,
                        changes: [
                            .dishEstimationStatusDeletion(
                                dishId: DishEstimationStatusRecordKindTests.removedDishId)
                        ])
                ]))

            #expect(
                try await store.dishEstimationStatuses() == [
                    DishEstimationStatusRecordKindTests.keptDishId: .deferredToNextDay
                ])
        }

        @Test("全消去で、状態がキャッシュから無くなること")
        func erasesWithEverythingElse() async throws {
            try await store.eraseAll()

            #expect(
                try store.container.mainContext.fetch(
                    FetchDescriptor<CachedDishEstimationStatus>()
                ).isEmpty)
        }
    }
}
