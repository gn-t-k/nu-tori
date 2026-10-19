import Foundation
import NuToriCore
import Testing

@Suite("ペース")
struct PaceTests {
    // swiftlint:disable:next no_parameterized_test
    @Test(
        "サーバーと同じ入力から、同じペースを返すこと",
        arguments: try SharedTestCases.decode(
            [TestCase].self, fromFileNamed: "pace.test-cases.json")
    )
    func matchesServer(testCase: TestCase) {
        let pace = Pace(
            judgedDay: testCase.judgedDay,
            goal: testCase.goal,
            achievedDay: testCase.achievedDay,
            weightTrend: testCase.weightTrend,
            weightRecordDays: testCase.weightRecordDays)

        #expect(pace == testCase.expected)
    }

    struct TestCase: Decodable, Sendable, CustomTestStringConvertible {
        let name: String
        let judgedDay: CalendarDay
        let weightTrend: WeightTrend
        let weightRecordDays: [CalendarDay]
        let goal: Goal
        let achievedDay: CalendarDay?
        let expected: Pace

        var testDescription: String { name }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            judgedDay = try container.decodeCalendarDay(forKey: .judgedOn)
            weightTrend = WeightTrend(
                days: try container.decode([InputTrendDay].self, forKey: .weightTrend).map(\.day))
            weightRecordDays = try container.decode([String].self, forKey: .weightRecordDays).map(
                calendarDay)
            goal = try container.decode(InputGoal.self, forKey: .goal).goal
            achievedDay = try container.decode(String?.self, forKey: .achievedOn).map(calendarDay)
            expected = try container.decode(ExpectedPace.self, forKey: .expected).pace
        }

        private enum CodingKeys: String, CodingKey {
            case name
            case judgedOn
            case weightTrend
            case weightRecordDays
            case goal
            case achievedOn
            case expected
        }
    }

    struct InputTrendDay: Decodable {
        let day: WeightTrend.Day

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            day = WeightTrend.Day(
                day: try container.decodeCalendarDay(forKey: .calendarDay),
                kilograms: try container.decode(Double.self, forKey: .trendKg))
        }

        private enum CodingKeys: String, CodingKey {
            case calendarDay
            case trendKg
        }
    }

    /// 入力はペースに効く値だけを持つ。ほかの値はペースに効かないので、決まった値で埋める
    struct InputGoal: Decodable {
        let goal: Goal

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let direction: Goal.Direction
            switch try container.decode(String.self, forKey: .direction) {
            case "maintain":
                direction = .maintain
            case "lose":
                direction = .lose(try Self.weightChange(in: container))
            case "gain":
                direction = .gain(try Self.weightChange(in: container))
            case let name:
                throw DecodingError.dataCorruptedError(
                    forKey: .direction, in: container, debugDescription: "知らない向き: \(name)")
            }
            goal = Goal(
                id: UUID(),
                startedDay: try container.decodeCalendarDay(forKey: .startedOn),
                startingWeightTrendKilograms: 72.4,
                targetWeightKilograms: try container.decode(Double.self, forKey: .targetWeightKg),
                decidedAt: Date(timeIntervalSince1970: 0),
                timeZone: .gmt,
                direction: direction,
                closure: nil
            )
        }

        private static func weightChange(
            in container: KeyedDecodingContainer<CodingKeys>
        ) throws -> Goal.WeightChange {
            Goal.WeightChange(
                deadlineDay: try container.decodeCalendarDay(forKey: .deadlineOn),
                pacePlan: .standard)
        }

        private enum CodingKeys: String, CodingKey {
            case direction
            case startedOn
            case deadlineOn
            case targetWeightKg
        }
    }

    /// 期待値の kg は 0.1 kg に丸めてあるので、0.1 kg 単位の整数にする
    struct ExpectedPace: Decodable {
        let pace: Pace

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            func tenths(_ key: CodingKeys) throws -> Int {
                Int((try container.decode(Double.self, forKey: key) * 10).rounded())
            }
            switch try container.decode(String.self, forKey: .status) {
            case "onTrack":
                pace = .onTrack(
                    actualTenthsOfKilogramPerWeek: try tenths(.actualKgPerWeek),
                    requiredTenthsOfKilogramPerWeek: try tenths(.requiredKgPerWeek))
            case "behind":
                pace = .behind(
                    shortfallTenthsOfKilogram: try tenths(.shortfallKg),
                    actualTenthsOfKilogramPerWeek: try tenths(.actualKgPerWeek),
                    requiredTenthsOfKilogramPerWeek: try tenths(.requiredKgPerWeek))
            case "inconclusive":
                pace = .inconclusive(
                    weightRecordDayCount: try container.decode(
                        Int.self, forKey: .weightRecordDayCount))
            case "pending":
                pace = .pending
            case "unavailable":
                pace = .unavailable
            case "maintenance":
                pace = .maintenance(
                    isWithinBand: try container.decode(Bool.self, forKey: .isWithinBand))
            case let status:
                throw DecodingError.dataCorruptedError(
                    forKey: .status, in: container, debugDescription: "知らない status: \(status)")
            }
        }

        private enum CodingKeys: String, CodingKey {
            case status
            case actualKgPerWeek
            case requiredKgPerWeek
            case shortfallKg
            case weightRecordDayCount
            case isWithinBand
        }
    }
}

private func calendarDay(_ text: String) throws -> CalendarDay {
    guard let day = CalendarDay(yearMonthDay: text) else {
        throw DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "YYYY-MM-DD の形でない: \(text)"))
    }
    return day
}

extension KeyedDecodingContainer {
    fileprivate func decodeCalendarDay(forKey key: Key) throws -> CalendarDay {
        try calendarDay(try decode(String.self, forKey: key))
    }
}
