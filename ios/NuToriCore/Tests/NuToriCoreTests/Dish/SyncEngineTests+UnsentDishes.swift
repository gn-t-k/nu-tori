import Foundation
import HTTPTypes
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("まだ送れていない料理")
    struct UnsentDishes {
        @Suite("料理を足したとき")
        struct AddedDish {
            @Suite("送る前")
            struct BeforeSync {
                let engine: SyncEngine
                let dishId: UUID

                init() async throws {
                    engine = .fixture(store: try await DishWrites.seededStore(), transport: .sync())
                    dishId = try #require(
                        try await engine.addDish(named: "味噌汁", toMeal: DishWrites.mealId)
                    ).id
                }

                @Test("まだ送れていない料理にすること")
                func isUnsent() async throws {
                    #expect(try await engine.unsentDishIds() == [dishId])
                }
            }

            @Suite("送ったとき")
            struct Synced {
                let engine: SyncEngine

                init() async throws {
                    engine = .fixture(store: try await DishWrites.seededStore(), transport: .sync())
                    _ = try #require(
                        try await engine.addDish(named: "味噌汁", toMeal: DishWrites.mealId))
                    _ = try await engine.sync()
                }

                @Test("まだ送れていない料理にしないこと")
                func isNotUnsent() async throws {
                    #expect(try await engine.unsentDishIds().isEmpty)
                }
            }
        }

        @Suite("名前を直したとき")
        struct RenamedDish {
            @Suite("送る前")
            struct BeforeSync {
                let engine: SyncEngine

                init() async throws {
                    engine = .fixture(store: try await DishWrites.seededStore(), transport: .sync())
                    try await engine.renameDish(id: DishWrites.dishId, to: "カツ丼")
                }

                @Test("まだ送れていない料理にすること")
                func isUnsent() async throws {
                    #expect(try await engine.unsentDishIds() == [DishWrites.dishId])
                }
            }

            @Suite("送って変更を取り切ったとき")
            struct Synced {
                let engine: SyncEngine

                init() async throws {
                    engine = .fixture(store: try await DishWrites.seededStore(), transport: .sync())
                    try await engine.renameDish(id: DishWrites.dishId, to: "カツ丼")
                    _ = try await engine.sync()
                }

                @Test("まだ送れていない料理にしないこと")
                func isNotUnsent() async throws {
                    #expect(try await engine.unsentDishIds().isEmpty)
                }
            }
        }

        @Suite("量だけを直したとき")
        struct QuantityCorrectedDish {
            let engine: SyncEngine

            init() async throws {
                engine = .fixture(store: try await DishWrites.seededStore(), transport: .sync())
                try await engine.correctDishQuantity(id: DishWrites.dishId, to: 1.5)
            }

            @Test("まだ送れていない料理にしないこと")
            func isNotUnsent() async throws {
                #expect(try await engine.unsentDishIds().isEmpty)
            }
        }

        @Suite("名前を直して送り終えたあと、変更を取りに行けなかったとき")
        struct PullFailed {
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() async throws {
                transport = .sync(pullStatus: .internalServerError)
                engine = .fixture(store: try await DishWrites.seededStore(), transport: transport)
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
    }
}
