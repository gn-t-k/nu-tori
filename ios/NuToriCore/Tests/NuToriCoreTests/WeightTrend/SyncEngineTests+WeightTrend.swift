import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("体重の傾向の同期")
    struct WeightTrendKind {
        static func page(_ changes: String, sequence: Int) -> String {
            """
            {"changes":[\(changes)],"hasMore":false,"nextAfterSequence":\(sequence),"startedOn":null}
            """
        }

        static let firstTrend = """
            {"sequence":1,"kind":"weight_trend","recordId":"weight_trend",
             "record":{"days":[{"calendarDay":"2026-09-20","trendKg":72.4},
               {"calendarDay":"2026-09-21","trendKg":72.35},{"calendarDay":"2026-09-22","trendKg":72.3}]}}
            """

        @Suite("傾向を持っていて、短い並びが届いたとき")
        struct PullingReplacement {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        WeightTrendKind.page(WeightTrendKind.firstTrend, sequence: 1),
                        WeightTrendKind.page(
                            """
                            {"sequence":2,"kind":"weight_trend","recordId":"weight_trend",
                             "record":{"days":[{"calendarDay":"2026-09-21","trendKg":72.5}]}}
                            """, sequence: 2),
                    ]))
                _ = try await engine.sync()
            }

            @Test("日ごとに差し替えず、届いた並びで置き換えること")
            func replacesWholeTrend() async throws {
                _ = try await engine.sync()

                #expect(
                    store.cache.weightTrend
                        == WeightTrend(days: [
                            .init(day: CalendarDay(year: 2026, month: 9, day: 21), kilograms: 72.5)
                        ]))
            }
        }

        @Suite("傾向を持っていて、体重記録が1つも無くなった印が届いたとき")
        struct PullingAbsence {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        WeightTrendKind.page(WeightTrendKind.firstTrend, sequence: 1),
                        WeightTrendKind.page(
                            """
                            {"sequence":2,"kind":"weight_trend_absence","recordId":"weight_trend","record":{}}
                            """, sequence: 2),
                    ]))
                _ = try await engine.sync()
            }

            @Test("傾向のキャッシュを空にすること")
            func clearsTrend() async throws {
                #expect(store.cache.weightTrend?.days.count == 3)

                _ = try await engine.sync()

                #expect(store.cache.weightTrend == nil)
            }
        }
    }
}
