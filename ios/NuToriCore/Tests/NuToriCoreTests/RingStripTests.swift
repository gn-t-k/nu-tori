import NuToriCore
import Testing

@Suite("1日の丸の帯")
struct RingStripTests {
    @Suite("使い始めた週")
    struct FirstWeek {
        let strip: RingStrip

        init() throws {
            // 2026-09-23 は水曜
            strip = RingStrip(
                timeline: Timeline(
                    input: Timeline.Input(
                        weightRecords: [
                            try .imported(73.0, at: "2026-09-22T06:48:00+09:00", in: "Asia/Tokyo"),
                            try .imported(72.8, at: "2026-09-24T06:48:00+09:00", in: "Asia/Tokyo"),
                        ], rejectedLines: [], meals: [], notices: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                    today: CalendarDay(year: 2026, month: 9, day: 24)
                )
            )
        }

        @Test("月曜を左端にし、使い始める前の日に丸を描かず、体重記録のある日に印を付けること")
        func placesSlotsFromMonday() {
            #expect(
                strip.weeks.first?.slots == [
                    .beforeFirstDay(CalendarDay(year: 2026, month: 9, day: 21)),
                    .beforeFirstDay(CalendarDay(year: 2026, month: 9, day: 22)),
                    .ring(
                        CalendarDay(year: 2026, month: 9, day: 23), DayRing(hasWeightRecord: false)),
                    .ring(
                        CalendarDay(year: 2026, month: 9, day: 24), DayRing(hasWeightRecord: true)),
                    .ring(
                        CalendarDay(year: 2026, month: 9, day: 25), DayRing(hasWeightRecord: false)),
                    .ring(
                        CalendarDay(year: 2026, month: 9, day: 26), DayRing(hasWeightRecord: false)),
                    .ring(
                        CalendarDay(year: 2026, month: 9, day: 27), DayRing(hasWeightRecord: false)),
                ])
        }

        @Test("使い始めた週より前へ送れないこと")
        func hasNoWeekBeforeFirstWeek() {
            #expect(strip.weeks.count == 1)
        }
    }

    @Suite("使い始めて何週かたったとき")
    struct SeveralWeeks {
        let strip: RingStrip

        init() {
            strip = RingStrip(
                timeline: Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [], meals: [], notices: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                    today: CalendarDay(year: 2026, month: 10, day: 7)
                )
            )
        }

        @Test("使い始めた週から今週まで古い順に並べること")
        func listsWeeksFromFirstWeekToThisWeek() {
            #expect(
                strip.weeks.map { $0.slots.first?.day } == [
                    CalendarDay(year: 2026, month: 9, day: 21),
                    CalendarDay(year: 2026, month: 9, day: 28),
                    CalendarDay(year: 2026, month: 10, day: 5),
                ])
        }
    }

    @Suite("今日より先の日に記録があるとき")
    struct RecordAfterToday {
        let strip: RingStrip

        init() throws {
            // 今日は日曜で、記録は次の週の月曜
            strip = RingStrip(
                timeline: Timeline(
                    input: Timeline.Input(
                        weightRecords: [
                            try .manual(72.4, at: "2026-09-28T07:12:00+09:00", in: "Asia/Tokyo")
                        ], rejectedLines: [], meals: [], notices: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 21),
                    today: CalendarDay(year: 2026, month: 9, day: 27)
                )
            )
        }

        @Test("その日のある週まで先へ送れること")
        func extendsToWeekOfRecord() {
            #expect(strip.weeks.count == 2)
        }

        @Test("その日に体重の印を付けること")
        func marksDayOfRecord() {
            #expect(
                strip.weeks.last?.slots.first
                    == .ring(
                        CalendarDay(year: 2026, month: 9, day: 28), DayRing(hasWeightRecord: true)))
        }
    }
}
