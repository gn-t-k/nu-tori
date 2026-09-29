import Foundation
import NuToriCore
import Testing

@Suite("体重の入力")
struct WeightEntryTests {
    @Suite("初期値")
    struct InitialValue {
        @Suite("体重記録が無いとき")
        struct NoRecords {
            let entry: WeightEntry

            init() {
                entry = WeightEntry(
                    weightRecords: [], today: CalendarDay(year: 2026, month: 9, day: 24))
            }

            @Test("空欄にすること")
            func isEmpty() {
                #expect(entry.initialValue == .empty)
            }
        }

        @Suite("今日の分が無く、いちばん新しい記録が取り込んだものとき")
        struct LatestIsImported {
            let entry: WeightEntry

            init() throws {
                entry = WeightEntry(
                    weightRecords: [
                        try .imported(72.37, at: "2026-09-22T06:48:00+09:00", in: "Asia/Tokyo"),
                        try .manual(72.9, at: "2026-09-21T07:12:00+09:00", in: "Asia/Tokyo"),
                    ],
                    today: CalendarDay(year: 2026, month: 9, day: 24)
                )
            }

            @Test("いちばん新しい記録の値を 0.1 kg に丸め、その日付を添えること")
            func usesRoundedLatestValueAndDay() {
                #expect(
                    entry.initialValue
                        == .previous(
                            kilograms: 72.4, day: CalendarDay(year: 2026, month: 9, day: 22)))
            }
        }

        @Suite("今日の分に手の記録が2件と、それより新しい取り込んだ記録があるとき")
        struct TodayHasManualRecords {
            let entry: WeightEntry

            init() throws {
                entry = WeightEntry(
                    weightRecords: [
                        try .manual(72.4, at: "2026-09-24T06:00:00+09:00", in: "Asia/Tokyo"),
                        try .manual(72.6, at: "2026-09-24T07:00:00+09:00", in: "Asia/Tokyo"),
                        try .imported(72.9, at: "2026-09-24T07:30:00+09:00", in: "Asia/Tokyo"),
                    ],
                    today: CalendarDay(year: 2026, month: 9, day: 24)
                )
            }

            @Test("今日の手の記録のうち、いちばん新しいものの値にすること")
            func usesLatestManualRecordOfToday() {
                #expect(
                    entry.initialValue
                        == .previous(
                            kilograms: 72.6, day: CalendarDay(year: 2026, month: 9, day: 24)))
            }
        }
    }

    @Suite("記録したときの書き込み")
    struct Write {
        @Suite("今日の分に手の記録があるとき")
        struct TodayHasManualRecord {
            let latestManualID: UUID
            let entry: WeightEntry
            let kilograms: Double
            let recordedAt: Date
            let recordedIn: TimeZone

            init() throws {
                latestManualID = UUID()
                entry = WeightEntry(
                    weightRecords: [
                        try .manual(72.4, at: "2026-09-24T06:00:00+09:00", in: "Asia/Tokyo"),
                        try .manual(
                            72.6, at: "2026-09-24T07:00:00+09:00", in: "Asia/Tokyo",
                            id: latestManualID,
                            version: 2),
                        try .imported(72.9, at: "2026-09-24T07:30:00+09:00", in: "Asia/Tokyo"),
                    ],
                    today: CalendarDay(year: 2026, month: 9, day: 24)
                )
                kilograms = 72.1
                recordedAt = try Date("2026-09-24T08:15:00+09:00", strategy: .iso8601)
                recordedIn = try #require(TimeZone(identifier: "Asia/Seoul"))
            }

            @Test("いちばん新しい手の記録を、記録した時点の値・時刻・タイムゾーンと、上げた版で直すこと")
            func correctsLatestManualRecord() {
                #expect(
                    entry.write(recording: kilograms, at: recordedAt, in: recordedIn)
                        == .correct(
                            WeightRecord(
                                id: latestManualID,
                                kilograms: kilograms,
                                instant: recordedAt,
                                timeZone: recordedIn,
                                inputSource: .manual,
                                version: 3
                            )
                        ))
            }
        }

        @Suite("今日の分が取り込んだ記録だけのとき")
        struct TodayHasOnlyImportedRecord {
            let entry: WeightEntry
            let kilograms: Double
            let recordedAt: Date
            let recordedIn: TimeZone

            init() throws {
                entry = WeightEntry(
                    weightRecords: [
                        try .manual(72.6, at: "2026-09-23T07:00:00+09:00", in: "Asia/Tokyo"),
                        try .imported(72.9, at: "2026-09-24T06:48:00+09:00", in: "Asia/Tokyo"),
                    ],
                    today: CalendarDay(year: 2026, month: 9, day: 24)
                )
                kilograms = 72.4
                recordedAt = try Date("2026-09-24T07:12:00+09:00", strategy: .iso8601)
                recordedIn = try #require(TimeZone(identifier: "Asia/Tokyo"))
            }

            @Test("新しい記録を作ること")
            func createsNewRecord() {
                #expect(
                    entry.write(recording: kilograms, at: recordedAt, in: recordedIn)
                        == .create(kilograms: kilograms, instant: recordedAt, timeZone: recordedIn))
            }
        }
    }

    @Suite("打ち間違いの判定")
    struct PossibleTypo {
        @Suite("前回の記録が無いとき")
        struct NoPreviousRecord {
            let entry: WeightEntry
            let kilograms: Double

            init() {
                entry = WeightEntry(
                    weightRecords: [], today: CalendarDay(year: 2026, month: 9, day: 24))
                kilograms = 72.4
            }

            @Test("打ち間違いとしないこと")
            func isNotTypo() {
                #expect(entry.possibleTypo(for: kilograms) == nil)
            }
        }

        @Suite("前回が 72.0 kg のとき")
        struct PreviousIs72Kilograms {
            @Suite("差が 5% に届かない値を入れたとき")
            struct BelowFivePercent {
                let entry: WeightEntry
                let kilograms: Double

                init() throws {
                    entry = WeightEntry(
                        weightRecords: [
                            try .manual(72.0, at: "2026-09-22T07:00:00+09:00", in: "Asia/Tokyo")
                        ],
                        today: CalendarDay(year: 2026, month: 9, day: 24)
                    )
                    kilograms = 75.5
                }

                @Test("打ち間違いとしないこと")
                func isNotTypo() {
                    #expect(entry.possibleTypo(for: kilograms) == nil)
                }
            }

            @Suite("ちょうど 5% 重い値を入れたとき")
            struct HeavierByFivePercent {
                let entry: WeightEntry
                let kilograms: Double

                init() throws {
                    entry = WeightEntry(
                        weightRecords: [
                            try .manual(72.0, at: "2026-09-22T07:00:00+09:00", in: "Asia/Tokyo")
                        ],
                        today: CalendarDay(year: 2026, month: 9, day: 24)
                    )
                    kilograms = 75.6
                }

                @Test("重いことと、差と、前回の日付を返すこと")
                func isHeavier() {
                    let typo = entry.possibleTypo(for: kilograms)
                    #expect(typo?.direction == .heavier)
                    #expect(typo?.differenceKilograms == 3.6)
                    #expect(typo?.previousDay == CalendarDay(year: 2026, month: 9, day: 22))
                }
            }

            @Suite("5% より軽い値を入れたとき")
            struct LighterBeyondFivePercent {
                let entry: WeightEntry
                let kilograms: Double

                init() throws {
                    entry = WeightEntry(
                        weightRecords: [
                            try .manual(72.0, at: "2026-09-22T07:00:00+09:00", in: "Asia/Tokyo")
                        ],
                        today: CalendarDay(year: 2026, month: 9, day: 24)
                    )
                    kilograms = 68.0
                }

                @Test("軽いことと、差を返すこと")
                func isLighter() {
                    let typo = entry.possibleTypo(for: kilograms)
                    #expect(typo?.direction == .lighter)
                    #expect(typo?.differenceKilograms == 4.0)
                }
            }
        }

        @Suite("前回が取り込んだ 72.04 kg で、75.6 kg を入れたとき")
        struct PreviousIsUnroundedImport {
            let entry: WeightEntry
            let kilograms: Double

            init() throws {
                entry = WeightEntry(
                    weightRecords: [
                        try .imported(72.04, at: "2026-09-22T06:48:00+09:00", in: "Asia/Tokyo")
                    ],
                    today: CalendarDay(year: 2026, month: 9, day: 24)
                )
                kilograms = 75.6
            }

            @Test("0.1 kg に丸めた前回の値と比べ、その差を返すこと")
            func comparesWithRoundedPreviousValue() {
                #expect(entry.possibleTypo(for: kilograms)?.differenceKilograms == 3.6)
            }
        }

        @Suite("今日の手の記録を置き換えるとき")
        struct ReplacingTodaysManualRecord {
            let entry: WeightEntry
            let kilograms: Double

            init() throws {
                entry = WeightEntry(
                    weightRecords: [
                        try .manual(72.0, at: "2026-09-23T07:00:00+09:00", in: "Asia/Tokyo"),
                        try .manual(82.0, at: "2026-09-24T07:00:00+09:00", in: "Asia/Tokyo"),
                    ],
                    today: CalendarDay(year: 2026, month: 9, day: 24)
                )
                kilograms = 72.2
            }

            @Test("置き換える記録を除いた、いちばん新しい記録と比べること")
            func comparesWithLatestExceptReplacedRecord() {
                #expect(entry.possibleTypo(for: kilograms) == nil)
            }
        }
    }

    @Suite("記録できる値")
    struct Recordable {
        @Suite("受け付ける範囲の中の値を入れたとき")
        struct InRange {
            let entry: WeightEntry
            let kilograms: Double

            init() {
                entry = WeightEntry(
                    weightRecords: [], today: CalendarDay(year: 2026, month: 9, day: 24))
                kilograms = 72.4
            }

            @Test("記録できること")
            func canRecord() {
                #expect(entry.canRecord(kilograms))
            }
        }

        @Suite("受け付ける範囲の外の値を入れたとき")
        struct OutOfRange {
            let entry: WeightEntry
            let kilograms: Double

            init() {
                entry = WeightEntry(
                    weightRecords: [], today: CalendarDay(year: 2026, month: 9, day: 24))
                kilograms = 19.9
            }

            @Test("記録できないこと")
            func cannotRecord() {
                #expect(!entry.canRecord(kilograms))
            }
        }
    }
}
