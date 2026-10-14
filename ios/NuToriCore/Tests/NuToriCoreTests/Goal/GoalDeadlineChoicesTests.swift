import NuToriCore
import Testing

@Suite("期限のページで選べる日")
struct GoalDeadlineChoicesTests {
    // swiftlint:disable:next no_parameterized_test
    @Test("選べるかを決めること", arguments: try TestCase.load())
    func decidesWhetherToAccept(testCase: TestCase) {
        #expect(
            GoalDeadlineChoices(startDay: testCase.startDay).contains(testCase.deadlineDay)
                == testCase.accepted)
    }

    struct TestCase: Decodable, Sendable, CustomTestStringConvertible {
        let name: String
        let startDay: CalendarDay
        let deadlineDay: CalendarDay
        let accepted: Bool

        var testDescription: String { name }

        static func load() throws -> [Self] {
            try SharedTestCases.decode(
                [Self].self, fromFileNamed: "accepted-deadline-days.test-cases.json")
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            startDay = try Self.decodeCalendarDay(in: container, forKey: .startedOn)
            deadlineDay = try Self.decodeCalendarDay(in: container, forKey: .deadlineOn)
            accepted = try container.decode(Bool.self, forKey: .accepted)
        }

        private static func decodeCalendarDay(
            in container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys
        ) throws -> CalendarDay {
            let text = try container.decode(String.self, forKey: key)
            guard let day = CalendarDay(yearMonthDay: text) else {
                throw DecodingError.dataCorruptedError(
                    forKey: key, in: container, debugDescription: "YYYY-MM-DD の形でない: \(text)")
            }
            return day
        }

        private enum CodingKeys: String, CodingKey {
            case name, startedOn, deadlineOn, accepted
        }
    }
}
