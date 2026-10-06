import Foundation
import HTTPTypes
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("まだ送れていない料理")
    struct UnsentDishes {
        let store: SyncBoxMock<RecordCacheMock>
        let transport: ClientTransportMock
        let engine: SyncEngine

        init() async throws {
            store = try await DishWrites.seededStore()
            transport = .sync()
            engine = .fixture(store: store, transport: transport)
        }

        @Test("足した料理は、送るまでまだ送れていない料理にすること")
        func addedDish() async throws {
            let dish = try #require(
                try await engine.addDish(named: "味噌汁", toMeal: DishWrites.mealId))

            #expect(try await engine.unsentDishIds() == [dish.id])
            _ = try await engine.sync()
            #expect(try await engine.unsentDishIds().isEmpty)
        }

        @Test("名前を直した料理は、送るまでまだ送れていない料理にすること")
        func renamedDish() async throws {
            try await engine.renameDish(id: DishWrites.dishId, to: "カツ丼")

            #expect(try await engine.unsentDishIds() == [DishWrites.dishId])
        }

        @Test("名前を直した料理は、送って変更を取り切ったら、まだ送れていない料理にしないこと")
        func renamedDishAfterSync() async throws {
            try await engine.renameDish(id: DishWrites.dishId, to: "カツ丼")
            _ = try await engine.sync()

            #expect(try await engine.unsentDishIds().isEmpty)
        }

        @Test("量だけを直した料理は、まだ送れていない料理にしないこと")
        func quantityCorrectedDish() async throws {
            try await engine.correctDishQuantity(id: DishWrites.dishId, to: 1.5)

            #expect(try await engine.unsentDishIds().isEmpty)
        }

        @Suite("送り終えたあと、変更を取りに行けなかったとき")
        struct PullFailed {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() async throws {
                store = try await DishWrites.seededStore()
                transport = .sync(pullStatus: .internalServerError)
                engine = .fixture(store: store, transport: transport)
                try await engine.renameDish(id: DishWrites.dishId, to: "カツ丼")
                _ = try await engine.sync()
            }

            // 料理ごとの推定の状態が届くまでは、前の状態のまま待っていない料理に見せない（#332 の「まだ送れていない」）
            @Test("名前を直した料理を、まだ送れていない料理のままにすること")
            func keepsRenamedDishUnsent() async throws {
                #expect(try await engine.unsentDishIds() == [DishWrites.dishId])
            }

            @Test("次の同期で、同じ書き込みの ID で送り直すこと")
            func resendsSameWrite() async throws {
                _ = try await engine.sync()

                let writeIds = try transport.pushBodies.map {
                    try #require($0.writes.first?.writeId)
                }
                #expect(writeIds.count == 2)
                #expect(Set(writeIds).count == 1)
            }
        }

        @Test("名前を直した書き込みも、料理を直す書き込みで送ること")
        func renameIsSentAsUpdate() async throws {
            try await engine.renameDish(id: DishWrites.dishId, to: "カツ丼")
            _ = try await engine.sync()

            let write = try #require(try transport.pushBodies.first?.writes.first)
            guard case .updateDish(_, let correction) = write else {
                Issue.record("料理を直す書き込みでない: \(write)")
                return
            }
            #expect(correction.name == "カツ丼")
        }
    }
}
