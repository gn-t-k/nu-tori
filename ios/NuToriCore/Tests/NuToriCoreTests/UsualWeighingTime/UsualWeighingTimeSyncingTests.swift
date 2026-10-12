import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("いつもの時刻の同期の形")
struct UsualWeighingTimeSyncingTests {
    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = UsualWeighingTimeSyncing()
        let cache = MemorySingleRecordCache<UsualWeighingTime>()
        let id = UUID()

        @Test("まだ届いていなければ、キャッシュに無いこと")
        func startsEmpty() throws {
            try syncing.apply([.unknown(kind: "note")], to: cache)

            #expect(cache.read() == nil)
        }

        @Test("届いた時刻がキャッシュに入ること")
        func storesArrivedTime() throws {
            try syncing.apply([.usualWeighingTime(.init(id: id, minuteOfDay: 435))], to: cache)

            #expect(cache.read() == UsualWeighingTime(id: id, minuteOfDay: 435))
        }

        @Test("続けて届いたら、最後に届いた時刻にすること")
        func keepsLatestTime() throws {
            try syncing.apply(
                [
                    .usualWeighingTime(.init(id: id, minuteOfDay: 435)),
                    .usualWeighingTime(.init(id: id, minuteOfDay: 450)),
                ], to: cache)

            #expect(cache.read() == UsualWeighingTime(id: id, minuteOfDay: 450))
        }

        @Test("時刻の無い変更は、キャッシュの時刻を変えないこと")
        func keepsTimeWithoutChange() throws {
            try syncing.apply([.usualWeighingTime(.init(id: id, minuteOfDay: 435))], to: cache)

            try syncing.apply([.weightTrendAbsence], to: cache)

            #expect(cache.read() == UsualWeighingTime(id: id, minuteOfDay: 435))
        }

        @Test("空にすると、時刻がキャッシュから無くなること")
        func erases() throws {
            try syncing.apply([.usualWeighingTime(.init(id: id, minuteOfDay: 435))], to: cache)

            try syncing.erase(cache)

            #expect(cache.read() == nil)
        }
    }
}
