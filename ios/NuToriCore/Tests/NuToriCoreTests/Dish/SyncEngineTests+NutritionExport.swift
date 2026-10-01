import Foundation
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("栄養をヘルスケアに書く呼び出し")
    struct NutritionExport {
        struct ExportFailure: Error {}

        @Suite("取りに行く頁が2つに分かれているとき")
        struct PullingTwoPages {
            let export: NutritionHealthExportMock
            let engine: SyncEngine

            init() throws {
                export = .ok()
                engine = .fixture(
                    store: try .ok(),
                    transport: .sync(pullPages: [
                        #"{"changes":[],"hasMore":true,"nextAfterSequence":1,"startedOn":null}"#,
                        #"{"changes":[],"hasMore":false,"nextAfterSequence":2,"startedOn":null}"#,
                    ]),
                    nutritionHealthExport: export
                )
            }

            @Test("頁を取り切ったあとに、1回だけ呼ぶこと")
            func exportsOnceAfterLastPage() async throws {
                _ = try await engine.sync()

                #expect(export.exportCount == 1)
            }
        }

        @Suite("取りに行く前に止まったとき")
        struct PullNotReached {
            let export: NutritionHealthExportMock
            let engine: SyncEngine

            init() throws {
                export = .ok()
                engine = .fixture(
                    store: try .ok(),
                    transport: .error(URLError(.notConnectedToInternet)),
                    nutritionHealthExport: export
                )
            }

            @Test("呼ばないこと")
            func doesNotExport() async throws {
                _ = try await engine.sync()

                #expect(export.exportCount == 0)
            }
        }

        @Suite("書けなかったとき")
        struct ExportFailed {
            let engine: SyncEngine

            init() throws {
                engine = .fixture(
                    store: try .ok(),
                    transport: .sync(),
                    nutritionHealthExport: NutritionHealthExportMock.error(ExportFailure())
                )
            }

            @Test("同期は終えたものとして返すこと")
            func finishesSync() async throws {
                let result = try await engine.sync()

                #expect(result == SyncResult(rejectedWrites: [], ending: .finished))
            }
        }

        @Suite("この端末で食事を消したとき")
        struct DeletingMeal {
            let export: NutritionHealthExportMock
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine
            let meal: Meal

            init() throws {
                export = .ok()
                store = try .ok()
                meal = try Meal.fixture(
                    eatenAt: "2026-09-22T12:10:00+09:00", sentAt: "2026-09-22T12:11:00+09:00")
                store.cache.upsert(meal)
                engine = .fixture(
                    store: store, transport: .sync(), nutritionHealthExport: export)
            }

            @Test("キャッシュから消したあとに、呼ぶこと")
            func exportsAfterRemoving() async throws {
                try await engine.deleteMeal(id: meal.id)

                #expect(store.cache.meals[meal.id] == nil)
                #expect(export.exportCount == 1)
            }
        }

        @Suite("食事を消したときに書けなかったとき")
        struct DeletingMealExportFailed {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine
            let meal: Meal

            init() throws {
                store = try .ok()
                meal = try Meal.fixture(
                    eatenAt: "2026-09-22T12:10:00+09:00", sentAt: "2026-09-22T12:11:00+09:00")
                store.cache.upsert(meal)
                engine = .fixture(
                    store: store, transport: .sync(),
                    nutritionHealthExport: NutritionHealthExportMock.error(ExportFailure()))
            }

            @Test("食事を消すことは成功させること")
            func stillDeletes() async throws {
                try await engine.deleteMeal(id: meal.id)

                #expect(store.cache.meals[meal.id] == nil)
            }
        }
    }
}
