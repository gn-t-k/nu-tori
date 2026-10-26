import NuToriCore
import Testing

@Suite("日ごとの体重の記録")
struct DailyWeightRecordsTests {
    @Suite("記録のある日が6日のとき")
    struct SixDays {
        let dailyRecords: DailyWeightRecords

        init() throws {
            dailyRecords = DailyWeightRecords(
                weightRecords: try (19...24).map { day in
                    try .manual(72.4, at: "2026-09-\(day)T07:12:00+09:00", in: "Asia/Tokyo")
                },
                firstDay: CalendarDay(year: 2026, month: 9, day: 1)
            )
        }

        @Test("新しい日から5日を並べること")
        func listsLatestFiveDays() {
            #expect(
                dailyRecords.latest.map(\.day)
                    == (20...24).reversed().map {
                        CalendarDay(year: 2026, month: 9, day: $0)
                    })
        }

        @Test("すべての記録には6日を並べ、その行を置くこと")
        func listsAllDays() {
            #expect(dailyRecords.all.count == 6)
            #expect(dailyRecords.all.last?.day == CalendarDay(year: 2026, month: 9, day: 19))
            #expect(dailyRecords.hasMore)
        }
    }

    @Suite("記録のある日が5日のとき")
    struct FiveDays {
        let dailyRecords: DailyWeightRecords

        init() throws {
            dailyRecords = DailyWeightRecords(
                weightRecords: try (20...24).map { day in
                    try .manual(72.4, at: "2026-09-\(day)T07:12:00+09:00", in: "Asia/Tokyo")
                },
                firstDay: CalendarDay(year: 2026, month: 9, day: 1)
            )
        }

        @Test("すべての記録への行を置かないこと")
        func hasNoMore() {
            #expect(dailyRecords.latest.count == 5)
            #expect(!dailyRecords.hasMore)
        }
    }

    @Suite("1日に複数の記録がある日を含むとき")
    struct DaysWithSeveralRecords {
        let earliestOnTuesday: WeightRecord
        let dailyRecords: DailyWeightRecords

        init() throws {
            earliestOnTuesday = try .imported(
                72.7, at: "2026-09-22T06:48:00+09:00", in: "Asia/Tokyo")
            dailyRecords = DailyWeightRecords(
                weightRecords: [
                    try .manual(72.8, at: "2026-09-22T07:12:00+09:00", in: "Asia/Tokyo"),
                    try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo"),
                    earliestOnTuesday,
                ],
                firstDay: CalendarDay(year: 2026, month: 9, day: 1)
            )
        }

        @Test("新しい順に1日1行で並べること")
        func listsOneRowPerDayNewestFirst() {
            #expect(
                dailyRecords.latest.map(\.day) == [
                    CalendarDay(year: 2026, month: 9, day: 24),
                    CalendarDay(year: 2026, month: 9, day: 22),
                ])
        }

        @Test("行にその日の代表値とほかの記録の数を持つこと")
        func rowHasRepresentativeWeight() {
            #expect(dailyRecords.latest.last?.record == earliestOnTuesday)
            #expect(dailyRecords.latest.last?.otherRecordCount == 1)
        }
    }

    @Suite("使い始める前の記録があるとき")
    struct RecordsBeforeFirstDay {
        let dailyRecords: DailyWeightRecords

        init() throws {
            dailyRecords = DailyWeightRecords(
                weightRecords: [
                    try .imported(72.9, at: "2026-09-19T06:48:00+09:00", in: "Asia/Tokyo"),
                    try .imported(72.7, at: "2026-09-22T06:48:00+09:00", in: "Asia/Tokyo"),
                    try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo"),
                ],
                firstDay: CalendarDay(year: 2026, month: 9, day: 23)
            )
        }

        @Test("使い始めた日からの記録だけを並べること")
        func listsOnlySinceFirstDay() {
            #expect(dailyRecords.all.map(\.day) == [CalendarDay(year: 2026, month: 9, day: 24)])
        }
    }
}
