import NuToriCore
import Testing

@Suite("最近の記録")
struct RecentWeightRecordsTests {
    @Suite("4週の枠")
    struct Window {
        let recent: RecentWeightRecords

        init() throws {
            // 今日の 2026-09-24 から 27 日前が 08-28
            recent = RecentWeightRecords(
                weightRecords: [
                    try .manual(73.5, at: "2026-08-27T07:00:00+09:00", in: "Asia/Tokyo"),
                    try .manual(73.4, at: "2026-08-28T07:00:00+09:00", in: "Asia/Tokyo"),
                ],
                firstDay: CalendarDay(year: 2026, month: 8, day: 1),
                today: CalendarDay(year: 2026, month: 9, day: 24)
            )
        }

        @Test("今日を含めた28日の分だけを並べること")
        func listsOnlyLast28Days() {
            #expect(recent.sinceFirstDay.map(\.day) == [CalendarDay(year: 2026, month: 8, day: 28)])
        }
    }

    @Suite("1日に複数の記録がある日を含むとき")
    struct DaysWithSeveralRecords {
        let earliestOnTuesday: WeightRecord
        let recent: RecentWeightRecords

        init() throws {
            earliestOnTuesday = try .imported(
                72.7, at: "2026-09-22T06:48:00+09:00", in: "Asia/Tokyo")
            recent = RecentWeightRecords(
                weightRecords: [
                    try .manual(72.8, at: "2026-09-22T07:12:00+09:00", in: "Asia/Tokyo"),
                    try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo"),
                    earliestOnTuesday,
                ],
                firstDay: CalendarDay(year: 2026, month: 9, day: 1),
                today: CalendarDay(year: 2026, month: 9, day: 24)
            )
        }

        @Test("新しい順に1日1行で並べること")
        func listsOneRowPerDayNewestFirst() {
            #expect(
                recent.sinceFirstDay.map(\.day) == [
                    CalendarDay(year: 2026, month: 9, day: 24),
                    CalendarDay(year: 2026, month: 9, day: 22),
                ])
        }

        @Test("行にその日の代表値とほかの記録の数を持つこと")
        func rowHasRepresentativeWeight() {
            #expect(recent.sinceFirstDay.last?.record == earliestOnTuesday)
            #expect(recent.sinceFirstDay.last?.otherRecordCount == 1)
        }
    }

    @Suite("使い始める前の記録があるとき")
    struct RecordsBeforeFirstDay {
        let recent: RecentWeightRecords

        init() throws {
            recent = RecentWeightRecords(
                weightRecords: [
                    try .imported(74.0, at: "2026-08-20T06:48:00+09:00", in: "Asia/Tokyo"),
                    try .imported(72.9, at: "2026-09-19T06:48:00+09:00", in: "Asia/Tokyo"),
                    try .imported(72.7, at: "2026-09-22T06:48:00+09:00", in: "Asia/Tokyo"),
                    try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo"),
                ],
                firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                today: CalendarDay(year: 2026, month: 9, day: 24)
            )
        }

        @Test("使い始めた日からの記録と分けること")
        func separatesSinceFirstDay() {
            #expect(recent.sinceFirstDay.map(\.day) == [CalendarDay(year: 2026, month: 9, day: 24)])
        }

        @Test("使い始める前の記録も4週の枠の中で新しい順に並べること")
        func listsBeforeFirstDayWithinWindow() {
            #expect(
                recent.beforeFirstDay.map(\.day) == [
                    CalendarDay(year: 2026, month: 9, day: 22),
                    CalendarDay(year: 2026, month: 9, day: 19),
                ])
        }
    }

    @Suite("今日より先の日に記録があるとき")
    struct RecordAfterToday {
        let recent: RecentWeightRecords

        init() throws {
            recent = RecentWeightRecords(
                weightRecords: [
                    try .manual(72.4, at: "2026-09-25T07:12:00+09:00", in: "Asia/Tokyo")
                ],
                firstDay: CalendarDay(year: 2026, month: 9, day: 1),
                today: CalendarDay(year: 2026, month: 9, day: 24)
            )
        }

        @Test("その日の記録も並べること")
        func listsDayAfterToday() {
            #expect(recent.sinceFirstDay.map(\.day) == [CalendarDay(year: 2026, month: 9, day: 25)])
        }
    }
}
