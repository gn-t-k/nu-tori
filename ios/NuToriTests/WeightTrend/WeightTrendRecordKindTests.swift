import Foundation
import NuToriAPI
import NuToriCore
import Testing

@testable import NuTori

@Suite("体重の傾向の種類")
@MainActor
struct WeightTrendRecordKindTests {
    let store: SwiftDataSyncStore

    init() throws {
        store = try SwiftDataSyncStore(inMemory: true)
    }

    @Test("体重の傾向は、届いた並びで置き換え、無くなった印で空にすること")
    func replacesAndClearsWeightTrend() async throws {
        func apply(_ change: SyncChange) async throws {
            try await store.apply(
                SyncBoxResult(kindChanges: [KindChanges(kind: .weightTrend, changes: [change])]))
        }

        try await apply(
            .weightTrend(
                SyncedWeightTrend(days: [
                    .init(calendarDay: "2026-09-20", trendKilograms: 72.4),
                    .init(calendarDay: "2026-09-21", trendKilograms: 72.35),
                ])))
        try await apply(
            .weightTrend(
                SyncedWeightTrend(days: [
                    .init(calendarDay: "2026-09-21", trendKilograms: 72.5),
                    .init(calendarDay: "2026-09-22", trendKilograms: 72.45),
                ])))

        #expect(
            try await store.weightTrend()
                == WeightTrend(days: [
                    .init(day: CalendarDay(year: 2026, month: 9, day: 21), kilograms: 72.5),
                    .init(day: CalendarDay(year: 2026, month: 9, day: 22), kilograms: 72.45),
                ]))

        try await apply(.weightTrendAbsence)

        #expect(try await store.weightTrend() == nil)
    }
}
