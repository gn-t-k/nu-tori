import NuToriCore
import Testing

@Suite("体重記録")
struct WeightRecordTests {
    @Suite("見せる時刻")
    struct ClockTimeOfRecord {
        let record: WeightRecord

        init() throws {
            record = try .manual(72.4, at: "2026-09-23T22:12:00Z", in: "Asia/Tokyo")
        }

        @Test("記録したときのタイムゾーンでの時計の時刻になること")
        func usesClockOfRecordedTimeZone() {
            #expect(record.clockTime == ClockTime(hour: 7, minute: 12))
        }
    }
}
