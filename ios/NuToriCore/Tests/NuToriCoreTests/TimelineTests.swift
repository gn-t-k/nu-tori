import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("タイムライン")
struct TimelineTests {
    @Suite("並べる日")
    struct DaysInRange {
        @Suite("記録が無いとき")
        struct NoRecords {
            let timeline: Timeline

            init() {
                timeline = Timeline(
                    input: Timeline.Input(weightRecords: [], rejectedLines: [], meals: [], rejectedMealLines: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                    today: CalendarDay(year: 2026, month: 9, day: 25)
                )
            }

            @Test("使い始めた日から今日まで1日ずつ並べること")
            func listsEveryDayFromFirstDayToToday() {
                #expect(
                    timeline.days.map(\.day) == [
                        CalendarDay(year: 2026, month: 9, day: 23),
                        CalendarDay(year: 2026, month: 9, day: 24),
                        CalendarDay(year: 2026, month: 9, day: 25),
                    ])
            }

            @Test("日のまとめで使い始めた日から今日まで送れること")
            func daySummaryMovesFromFirstDayToToday() {
                #expect(
                    timeline.dayRange
                        == CalendarDay(
                            year: 2026, month: 9, day: 23)...CalendarDay(
                            year: 2026, month: 9, day: 25))
            }
        }

        @Suite("今日より先の日に記録があるとき")
        struct RecordAfterToday {
            let timeline: Timeline

            init() throws {
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [
                            try .manual(72.4, at: "2026-09-25T07:12:00+09:00", in: "Asia/Tokyo")
                        ], rejectedLines: [], meals: [], rejectedMealLines: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                    today: CalendarDay(year: 2026, month: 9, day: 24)
                )
            }

            @Test("記録のある先の日まで並べること")
            func listsUpToDayOfRecord() {
                #expect(timeline.days.last?.day == CalendarDay(year: 2026, month: 9, day: 25))
            }

            @Test("日のまとめで記録のある先の日まで送れること")
            func daySummaryMovesUpToDayOfRecord() {
                #expect(timeline.dayRange.upperBound == CalendarDay(year: 2026, month: 9, day: 25))
            }
        }

        @Suite("使い始める前の記録があるとき")
        struct RecordBeforeFirstDay {
            let timeline: Timeline

            init() throws {
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [
                            try .imported(73.0, at: "2026-09-20T06:48:00+09:00", in: "Asia/Tokyo")
                        ], rejectedLines: [], meals: [], rejectedMealLines: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                    today: CalendarDay(year: 2026, month: 9, day: 23)
                )
            }

            @Test("使い始める前の記録を並べないこと")
            func omitsRecordBeforeFirstDay() {
                #expect(timeline.days.map(\.day) == [CalendarDay(year: 2026, month: 9, day: 23)])
                #expect(timeline.days.map(\.items) == [[]])
            }
        }

        @Suite("使い始めた日のうちに西へ移り、今日が使い始めた日より前になったとき")
        struct TodayBeforeFirstDay {
            let timeline: Timeline

            init() {
                timeline = Timeline(
                    input: Timeline.Input(weightRecords: [], rejectedLines: [], meals: [], rejectedMealLines: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 24),
                    today: CalendarDay(year: 2026, month: 9, day: 23)
                )
            }

            @Test("使い始めた日だけを並べること")
            func listsOnlyFirstDay() {
                #expect(timeline.days.map(\.day) == [CalendarDay(year: 2026, month: 9, day: 24)])
            }
        }
    }

    @Suite("日への振り分け")
    struct PlacingRecords {
        @Suite("タイムゾーンの違う記録が同じ日にあるとき")
        struct RecordsInDifferentTimeZones {
            let tokyoMorning: WeightRecord
            let losAngelesMorning: WeightRecord
            let timeline: Timeline

            init() throws {
                // 時計の時刻は東京が 8:00、ロサンゼルスが 7:00 だが、実際の時刻は東京のほうが早い
                tokyoMorning = try .manual(72.4, at: "2026-09-24T08:00:00+09:00", in: "Asia/Tokyo")
                losAngelesMorning = try .manual(
                    72.6, at: "2026-09-24T07:00:00-07:00", in: "America/Los_Angeles")
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [losAngelesMorning, tokyoMorning], rejectedLines: [], meals: [], rejectedMealLines: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                    today: CalendarDay(year: 2026, month: 9, day: 24)
                )
            }

            @Test("記録したときのタイムゾーンでの日に入れること")
            func placesRecordsInDayOfRecordedTimeZone() {
                #expect(timeline.days.map(\.items.count) == [0, 2])
            }

            @Test("同じ日の中を実際の時刻の順に並べること")
            func sortsRecordsByInstant() {
                #expect(
                    timeline.days.last?.items == [
                        .weightRecord(tokyoMorning), .weightRecord(losAngelesMorning),
                    ])
            }
        }
    }

    @Suite("受け付けなかった行の置き場")
    struct PlacingRejectedLines {
        static let day = CalendarDay(year: 2026, month: 9, day: 24)

        @Suite("サーバーに記録が無いとき")
        struct NoValueOnServer {
            let before: WeightRecord
            let after: WeightRecord
            let line: RejectedWeightLine
            let timeline: Timeline

            init() throws {
                before = try .manual(72.0, at: "2026-09-24T06:00:00+09:00", in: "Asia/Tokyo")
                after = try .manual(72.8, at: "2026-09-24T21:00:00+09:00", in: "Asia/Tokyo")
                let rejected = try WeightRecord.manual(
                    72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo", version: 1)
                line = RejectedWeightLine(record: rejected, serverHasValue: false)
                timeline = Timeline(
                    input: Timeline.Input(weightRecords: [after, before], rejectedLines: [line], meals: [], rejectedMealLines: []),
                    firstDay: PlacingRejectedLines.day,
                    today: PlacingRejectedLines.day
                )
            }

            @Test("作った記録の時刻の位置に、行を置くこと")
            func placesLineAtItsInstant() {
                #expect(
                    timeline.days.first?.items == [
                        .weightRecord(before), .rejectedWeightLine(line), .weightRecord(after),
                    ])
            }
        }

        @Suite("サーバーに記録の値があるとき")
        struct ValueOnServer {
            let first: WeightRecord
            let restored: WeightRecord
            let line: RejectedWeightLine
            let timeline: Timeline

            init() throws {
                first = try .manual(72.0, at: "2026-09-24T06:00:00+09:00", in: "Asia/Tokyo")
                restored = try .manual(
                    72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo", version: 2)
                line = RejectedWeightLine(record: restored, serverHasValue: true)
                timeline = Timeline(
                    input: Timeline.Input(weightRecords: [restored, first], rejectedLines: [line], meals: [], rejectedMealLines: []),
                    firstDay: PlacingRejectedLines.day,
                    today: PlacingRejectedLines.day
                )
            }

            @Test("その値の記録のすぐ下に、行を置くこと")
            func placesLineBelowRestoredRecord() {
                #expect(
                    timeline.days.first?.items == [
                        .weightRecord(first), .weightRecord(restored), .rejectedWeightLine(line),
                    ])
            }
        }

        @Suite("直した記録の版が 2 でも、サーバーに記録が無いとき")
        struct CorrectedVersionButNoValueOnServer {
            let before: WeightRecord
            let after: WeightRecord
            let line: RejectedWeightLine
            let timeline: Timeline

            init() throws {
                before = try .manual(72.0, at: "2026-09-24T06:00:00+09:00", in: "Asia/Tokyo")
                after = try .manual(72.8, at: "2026-09-24T21:00:00+09:00", in: "Asia/Tokyo")
                let corrected = try WeightRecord.manual(
                    72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo", version: 2)
                line = RejectedWeightLine(record: corrected, serverHasValue: false)
                timeline = Timeline(
                    input: Timeline.Input(weightRecords: [after, before], rejectedLines: [line], meals: [], rejectedMealLines: []),
                    firstDay: PlacingRejectedLines.day,
                    today: PlacingRejectedLines.day
                )
            }

            @Test("版でなく、サーバーの値の有無で決めて、記録の時刻の位置に行を置くこと")
            func placesLineAtItsInstant() {
                #expect(
                    timeline.days.first?.items == [
                        .weightRecord(before), .rejectedWeightLine(line), .weightRecord(after),
                    ])
            }
        }

        @Suite("別の日の行があるとき")
        struct LineOnAnotherDay {
            let timeline: Timeline

            init() throws {
                let rejected = try WeightRecord.manual(
                    72.4, at: "2026-09-25T07:12:00+09:00", in: "Asia/Tokyo", version: 1)
                let line = RejectedWeightLine(record: rejected, serverHasValue: false)
                timeline = Timeline(
                    input: Timeline.Input(weightRecords: [], rejectedLines: [line], meals: [], rejectedMealLines: []),
                    firstDay: PlacingRejectedLines.day,
                    today: CalendarDay(year: 2026, month: 9, day: 25)
                )
            }

            @Test("その日にだけ置くこと")
            func placesOnlyOnItsDay() {
                #expect(timeline.days.map(\.items.count) == [0, 1])
            }
        }
    }

    @Suite("日の丸")
    struct DayRingOfDay {
        @Suite("体重記録のある日と無い日")
        struct WithAndWithoutRecord {
            let timeline: Timeline

            init() throws {
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [
                            try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                        ], rejectedLines: [], meals: [], rejectedMealLines: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                    today: CalendarDay(year: 2026, month: 9, day: 24)
                )
            }

            @Test("体重を記録した日だけ、記録したことを持つこと")
            func marksOnlyDayOfRecord() {
                #expect(
                    timeline.days.map(\.ring) == [
                        DayRing(hasWeightRecord: false), DayRing(hasWeightRecord: true),
                    ])
            }
        }

        @Suite("記録できなかった行だけがある日")
        struct OnlyRejectedLine {
            let timeline: Timeline

            init() throws {
                let rejected = try WeightRecord.manual(
                    72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo", version: 1)
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [],
                        rejectedLines: [
                            RejectedWeightLine(record: rejected, serverHasValue: false)
                        ], meals: [], rejectedMealLines: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 24),
                    today: CalendarDay(year: 2026, month: 9, day: 24)
                )
            }

            @Test("記録したことにしないこと")
            func doesNotMarkRing() {
                #expect(timeline.days.first?.ring == DayRing(hasWeightRecord: false))
            }
        }
    }

    @Suite("日の代表値")
    struct RepresentativeWeightOfDay {
        @Suite("記録の無い日")
        struct DayWithoutRecords {
            let timeline: Timeline

            init() {
                timeline = Timeline(
                    input: Timeline.Input(weightRecords: [], rejectedLines: [], meals: [], rejectedMealLines: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 24),
                    today: CalendarDay(year: 2026, month: 9, day: 24)
                )
            }

            @Test("代表値が無いこと")
            func hasNoRepresentativeWeight() {
                #expect(timeline.days.first?.representativeWeight == nil)
            }
        }

        @Suite("1日に3件の記録がある日")
        struct DayWithThreeRecords {
            let earliest: WeightRecord
            let timeline: Timeline

            init() throws {
                earliest = try .imported(72.3, at: "2026-09-24T06:48:00+09:00", in: "Asia/Tokyo")
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [
                            try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo"),
                            earliest,
                            try .manual(72.9, at: "2026-09-24T21:30:00+09:00", in: "Asia/Tokyo"),
                        ], rejectedLines: [], meals: [], rejectedMealLines: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 24),
                    today: CalendarDay(year: 2026, month: 9, day: 24)
                )
            }

            @Test("その日の最初の記録を代表にすること")
            func usesEarliestRecordAsRepresentative() {
                #expect(timeline.days.first?.representativeWeight?.record == earliest)
            }

            @Test("ほかの記録の数を2件と数えること")
            func countsOtherRecords() {
                #expect(timeline.days.first?.representativeWeight?.otherRecordCount == 2)
            }
        }
    }
}
