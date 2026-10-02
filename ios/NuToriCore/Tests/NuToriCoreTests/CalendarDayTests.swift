import Foundation
import NuToriCore
import Testing

@Suite("日と週の区切り")
struct CalendarDayTests {
    @Suite("日の区切り")
    struct ContainingInstant {
        // swiftlint:disable:next no_parameterized_test
        @Test(
            "時刻に時差を足した UTC の日付の日に入れること",
            arguments: try SharedTestCases.decode(
                [TestCase].self, fromFileNamed: "calendar-day.test-cases.json")
        )
        func placesInstantInDayOfUTCOffset(testCase: TestCase) {
            #expect(
                CalendarDay(
                    containing: testCase.instant, utcOffsetSeconds: testCase.utcOffsetSeconds)
                    == testCase.calendarDay
            )
        }

        struct TestCase: Decodable, Sendable, CustomTestStringConvertible {
            let name: String
            let instant: Date
            let utcOffsetSeconds: Int
            let calendarDay: CalendarDay

            var testDescription: String { name }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                name = try container.decode(String.self, forKey: .name)
                instant = try container.decode(Date.self, forKey: .instant)
                utcOffsetSeconds = try container.decode(Int.self, forKey: .utcOffsetSeconds)
                calendarDay = try container.decodeCalendarDay(forKey: .calendarDay)
            }

            private enum CodingKeys: String, CodingKey {
                case name
                case instant
                case utcOffsetSeconds
                case calendarDay
            }
        }
    }

    @Suite("タイムゾーンから出す日の区切り")
    struct ContainingInstantInTimeZone {
        // swiftlint:disable:next no_parameterized_test
        @Test(
            "その時刻の時差から出した日に入れること",
            arguments: try SharedTestCases.decode(
                [TestCase].self, fromFileNamed: "calendar-day-in-time-zone.test-cases.json")
        )
        func placesInstantInDayOfUTCOffsetInTimeZone(testCase: TestCase) {
            #expect(
                CalendarDay(containing: testCase.instant, in: testCase.timeZone)
                    == testCase.calendarDay
            )
        }

        // swiftlint:disable:next no_parameterized_test
        @Test(
            "その時刻の UTC との時差を秒で返すこと",
            arguments: try SharedTestCases.decode(
                [TestCase].self, fromFileNamed: "calendar-day-in-time-zone.test-cases.json")
        )
        func returnsUTCOffsetAtInstant(testCase: TestCase) {
            #expect(
                testCase.timeZone.secondsFromGMT(for: testCase.instant)
                    == testCase.utcOffsetSeconds
            )
        }

        struct TestCase: Decodable, Sendable, CustomTestStringConvertible {
            let name: String
            let instant: Date
            let timeZone: TimeZone
            let utcOffsetSeconds: Int
            let calendarDay: CalendarDay

            var testDescription: String { name }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                name = try container.decode(String.self, forKey: .name)
                instant = try container.decode(Date.self, forKey: .instant)
                timeZone = try container.decodeTimeZone(forKey: .timeZone)
                utcOffsetSeconds = try container.decode(Int.self, forKey: .utcOffsetSeconds)
                calendarDay = try container.decodeCalendarDay(forKey: .calendarDay)
            }

            private enum CodingKeys: String, CodingKey {
                case name
                case instant
                case timeZone
                case utcOffsetSeconds
                case calendarDay
            }
        }
    }

    @Suite("週の区切り")
    struct StartOfWeek {
        // swiftlint:disable:next no_parameterized_test
        @Test(
            "その週の月曜から始まる週に入れること",
            arguments: try SharedTestCases.decode(
                [TestCase].self, fromFileNamed: "start-of-week.test-cases.json")
        )
        func placesDayInWeekStartingOnMonday(testCase: TestCase) {
            #expect(testCase.calendarDay.startOfWeek == testCase.startOfWeek)
        }

        struct TestCase: Decodable, Sendable, CustomTestStringConvertible {
            let name: String
            let calendarDay: CalendarDay
            let startOfWeek: CalendarDay

            var testDescription: String { name }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                name = try container.decode(String.self, forKey: .name)
                calendarDay = try container.decodeCalendarDay(forKey: .calendarDay)
                startOfWeek = try container.decodeCalendarDay(forKey: .startOfWeek)
            }

            private enum CodingKeys: String, CodingKey {
                case name
                case calendarDay
                case startOfWeek
            }
        }
    }

    @Suite("日の前後")
    struct Ordering {
        @Suite("月をまたぐ2つの日")
        struct AcrossMonths {
            let earlier: CalendarDay
            let later: CalendarDay

            init() {
                earlier = CalendarDay(year: 2026, month: 9, day: 30)
                later = CalendarDay(year: 2026, month: 10, day: 1)
            }

            @Test("暦の順に比べること")
            func comparesInCalendarOrder() {
                #expect(earlier < later)
            }
        }

        @Suite("年をまたぐ2つの日")
        struct AcrossYears {
            let earlier: CalendarDay
            let later: CalendarDay

            init() {
                earlier = CalendarDay(year: 2025, month: 12, day: 31)
                later = CalendarDay(year: 2026, month: 1, day: 1)
            }

            @Test("暦の順に比べること")
            func comparesInCalendarOrder() {
                #expect(earlier < later)
            }
        }
    }

    @Suite("日の足し引き")
    struct Arithmetic {
        @Suite("月の最後の日に1日足すとき")
        struct AddingOneDayToLastDayOfMonth {
            let day: CalendarDay
            let days: Int

            init() {
                day = CalendarDay(year: 2026, month: 9, day: 30)
                days = 1
            }

            @Test("次の月の1日になること")
            func becomesFirstDayOfNextMonth() {
                #expect(day.advanced(by: days) == CalendarDay(year: 2026, month: 10, day: 1))
            }
        }

        @Suite("年の最初の日から1日引くとき")
        struct SubtractingOneDayFromFirstDayOfYear {
            let day: CalendarDay
            let days: Int

            init() {
                day = CalendarDay(year: 2026, month: 1, day: 1)
                days = -1
            }

            @Test("前の年の最後の日になること")
            func becomesLastDayOfPreviousYear() {
                #expect(day.advanced(by: days) == CalendarDay(year: 2025, month: 12, day: 31))
            }
        }

        @Suite("うるう年の2月28日に1日足すとき")
        struct AddingOneDayToFebruary28InLeapYear {
            let day: CalendarDay
            let days: Int

            init() {
                day = CalendarDay(year: 2028, month: 2, day: 28)
                days = 1
            }

            @Test("2月29日になること")
            func becomesLeapDay() {
                #expect(day.advanced(by: days) == CalendarDay(year: 2028, month: 2, day: 29))
            }
        }

        @Suite("月をまたぐ2つの日")
        struct TwoDaysAcrossMonths {
            let start: CalendarDay
            let end: CalendarDay

            init() {
                start = CalendarDay(year: 2026, month: 9, day: 23)
                end = CalendarDay(year: 2026, month: 10, day: 1)
            }

            @Test("あいだの日数を数えること")
            func countsDaysBetween() {
                #expect(start.distance(to: end) == 8)
            }
        }
    }

    @Suite("YYYY-MM-DD から読む")
    struct YearMonthDay {
        @Suite("うるう年の2月29日のとき")
        struct LeapDay {
            let text: String

            init() {
                text = "2028-02-29"
            }

            @Test("その日として読むこと")
            func readsTheDay() {
                #expect(
                    CalendarDay(yearMonthDay: text) == CalendarDay(year: 2028, month: 2, day: 29))
            }
        }

        @Suite("暦に無い日のとき")
        struct NonexistentDay {
            let text: String

            init() {
                text = "2026-02-31"
            }

            @Test("読めないこと")
            func cannotRead() {
                #expect(CalendarDay(yearMonthDay: text) == nil)
            }
        }
    }
}

extension KeyedDecodingContainer {
    fileprivate func decodeTimeZone(forKey key: Key) throws -> TimeZone {
        let identifier = try decode(String.self, forKey: key)
        guard let timeZone = TimeZone(identifier: identifier) else {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: self, debugDescription: "知らないタイムゾーン: \(identifier)")
        }
        return timeZone
    }

    fileprivate func decodeCalendarDay(forKey key: Key) throws -> CalendarDay {
        let text = try decode(String.self, forKey: key)
        let components = text.split(separator: "-").compactMap { Int($0) }
        guard components.count == 3 else {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: self, debugDescription: "YYYY-MM-DD の形でない: \(text)")
        }
        return CalendarDay(year: components[0], month: components[1], day: components[2])
    }
}
