import Foundation
import NuToriCore
import Testing

@Suite("その日の1日の目安")
struct DailyGuideForDayTests {
    // swiftlint:disable:next no_parameterized_test
    @Test(
        "その日を含む目標と、その目標の当てる始まりの日がその日以前で最も遅い1日の目安を返すこと",
        arguments: try SharedTestCases.decode(
            [TestCase].self, fromFileNamed: "daily-guide-for-day.test-cases.json")
    )
    func findsGuideForDay(testCase: TestCase) {
        let found = DailyGuideForDay(
            on: testCase.calendarDay, goals: testCase.goals, dailyGuides: testCase.dailyGuides)

        #expect(found?.goal.id == testCase.goalId)
        #expect(found?.dailyGuide?.id == testCase.dailyGuideId)
    }

    struct TestCase: Decodable, Sendable, CustomTestStringConvertible {
        let name: String
        let calendarDay: CalendarDay
        let goals: [Goal]
        let dailyGuides: [DailyGuide]
        let goalId: UUID?
        let dailyGuideId: UUID?

        var testDescription: String { name }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            calendarDay = try container.decodeCalendarDay(forKey: .calendarDay)
            goals = try container.decode([InputGoal].self, forKey: .goals).map(\.goal)
            dailyGuides = try container.decode([InputDailyGuide].self, forKey: .dailyGuides).map(
                \.dailyGuide)
            goalId = try container.decode(UUID?.self, forKey: .goalId)
            dailyGuideId = try container.decode(UUID?.self, forKey: .dailyGuideId)
        }

        private enum CodingKeys: String, CodingKey {
            case name
            case calendarDay
            case goals
            case dailyGuides
            case goalId
            case dailyGuideId
        }
    }

    /// 入力は引き方に使う値だけを持つ。ほかの値は引き方に効かないので、決まった値で埋める
    struct InputGoal: Decodable {
        let goal: Goal

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let id = try container.decode(UUID.self, forKey: .id)
            // 閉じていない目標は、JSON に終わった日のキーが無い
            let closure: Goal.Closure? =
                container.contains(.endedOn)
                ? Goal.Closure(
                    endedDay: try container.decodeCalendarDay(forKey: .endedOn), nextGoalId: UUID())
                : nil
            goal = Goal(
                id: id,
                startedDay: try container.decodeCalendarDay(forKey: .startedOn),
                startingWeightTrendKilograms: 65.0,
                targetWeightKilograms: 65.0,
                decidedAt: try container.decode(Date.self, forKey: .decidedAt),
                timeZone: .gmt,
                direction: .maintain,
                closure: closure
            )
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case startedOn
            case decidedAt
            case endedOn
        }
    }

    struct InputDailyGuide: Decodable {
        let dailyGuide: DailyGuide

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            dailyGuide = DailyGuide(
                id: try container.decode(UUID.self, forKey: .id),
                goalId: try container.decode(UUID.self, forKey: .goalId),
                expenditureEstimateId: UUID(),
                effectiveDay: try container.decodeCalendarDay(forKey: .effectiveOn),
                energyKilocalories: 1850,
                proteinGrams: 130,
                fatGrams: 50,
                carbohydrateGrams: 220,
                limitHits: []
            )
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case goalId
            case effectiveOn
        }
    }
}

extension KeyedDecodingContainer {
    fileprivate func decodeCalendarDay(forKey key: Key) throws -> CalendarDay {
        let text = try decode(String.self, forKey: key)
        guard let day = CalendarDay(yearMonthDay: text) else {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: self, debugDescription: "YYYY-MM-DD の形でない: \(text)")
        }
        return day
    }
}
