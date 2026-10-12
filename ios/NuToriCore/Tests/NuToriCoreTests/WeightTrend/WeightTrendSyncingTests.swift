import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("体重の傾向の同期の形")
struct WeightTrendSyncingTests {
    @Suite("傾向を持っていて、取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = WeightTrendSyncing()
        let cache = MemorySingleRecordCache<WeightTrend>()
        let held = WeightTrend.starting(
            CalendarDay(year: 2026, month: 9, day: 20), kilograms: [72.4, 72.35, 72.3])

        init() throws {
            try syncing.apply([.weightTrend(Self.synced(held))], to: cache)
        }

        static func synced(_ trend: WeightTrend) -> SyncedWeightTrend {
            SyncedWeightTrend(
                days: trend.days.map {
                    .init(calendarDay: $0.day.yearMonthDay, trendKilograms: $0.kilograms)
                })
        }

        @Test("届いた並びがキャッシュに入ること")
        func storesArrivedTrend() {
            #expect(cache.read() == held)
        }

        @Test("短い並びが届いたら、日ごとに差し替えず、届いた並びで置き換えること")
        func replacesWholeTrend() throws {
            let shorter = WeightTrend.starting(
                CalendarDay(year: 2026, month: 9, day: 21), kilograms: [72.5])

            try syncing.apply([.weightTrend(Self.synced(shorter))], to: cache)

            #expect(cache.read() == shorter)
        }

        @Test("日付が読めない日を読み飛ばして置き換えること")
        func skipsUnreadableDays() throws {
            try syncing.apply(
                [
                    .weightTrend(
                        SyncedWeightTrend(days: [
                            .init(calendarDay: "9月21日", trendKilograms: 72.6),
                            .init(calendarDay: "2026-09-22", trendKilograms: 72.5),
                        ]))
                ], to: cache)

            #expect(
                cache.read()
                    == WeightTrend.starting(
                        CalendarDay(year: 2026, month: 9, day: 22), kilograms: [72.5]))
        }

        @Test("体重記録が1つも無くなった印で、空にすること")
        func clearsOnAbsence() throws {
            try syncing.apply([.weightTrendAbsence], to: cache)

            #expect(cache.read() == nil)
        }

        @Test("日が1つも無い並びが届いたら、空にすること")
        func clearsOnEmptyTrend() throws {
            try syncing.apply([.weightTrend(SyncedWeightTrend(days: []))], to: cache)

            #expect(cache.read() == nil)
        }

        @Test("無くなった印のあとに並びが届いたら、最後に届いた並びにすること")
        func keepsLatestUpdate() throws {
            try syncing.apply([.weightTrendAbsence, .weightTrend(Self.synced(held))], to: cache)

            #expect(cache.read() == held)
        }

        @Test("傾向の無い変更は、キャッシュの傾向を変えないこと")
        func keepsTrendWithoutChange() throws {
            try syncing.apply([.weightRecordDeletion(recordId: UUID())], to: cache)

            #expect(cache.read() == held)
        }

        @Test("空にすると、傾向がキャッシュから無くなること")
        func erases() throws {
            try syncing.erase(cache)

            #expect(cache.read() == nil)
        }
    }
}
