import Foundation
import NuToriCore
import Testing

@Suite("日と週の区切り")
struct CalendarDayTests {
    @Suite("日の区切り")
    struct ContainingInstant {
        // swiftlint:disable:next no_parameterized_test
        @Test(
            "記録したときのタイムゾーンでの日付の日に入れること",
            arguments: try SharedTestCases.decode(
                [TestCase].self, fromFileNamed: "calendar-day.test-cases.json")
        )
        func placesInstantInDayOfRecordedTimeZone(testCase: TestCase) {
            #expect(
                CalendarDay(containing: testCase.instant, in: testCase.timeZone)
                    == testCase.calendarDay
            )
        }

        struct TestCase: Decodable, Sendable, CustomTestStringConvertible {
            let name: String
            let instant: Date
            let timeZone: TimeZone
            let calendarDay: CalendarDay

            var testDescription: String { name }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                name = try container.decode(String.self, forKey: .name)
                instant = try container.decode(Date.self, forKey: .instant)
                timeZone = try container.decodeTimeZone(forKey: .timeZone)
                calendarDay = try container.decodeCalendarDay(forKey: .calendarDay)
            }

            private enum CodingKeys: String, CodingKey {
                case name
                case instant
                case timeZone
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
