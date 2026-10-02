import Foundation
import NuToriCore
import Testing

@Suite("日の代表値")
struct RepresentativeWeightTests {
    // swiftlint:disable:next no_parameterized_test
    @Test(
        "日ごとに実際の時刻でいちばん早い記録を、日の順に返すこと",
        arguments: try SharedTestCases.decode(
            [TestCase].self, fromFileNamed: "daily-representative-weight.test-cases.json")
    )
    func picksEarliestRecordPerDay(testCase: TestCase) {
        let representatives = RepresentativeWeight.daily(of: testCase.weightRecords)

        #expect(
            representatives.map {
                Expected(day: $0.day, weightRecordId: $0.record.id, kilograms: $0.record.kilograms)
            } == testCase.representativeWeights)
    }

    struct TestCase: Decodable, Sendable, CustomTestStringConvertible {
        let name: String
        let weightRecords: [WeightRecord]
        let representativeWeights: [Expected]

        var testDescription: String { name }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            weightRecords = try container.decode([InputRecord].self, forKey: .weightRecords).map(
                \.weightRecord)
            representativeWeights = try container.decode(
                [Expected].self, forKey: .representativeWeights)
        }

        private enum CodingKeys: String, CodingKey {
            case name
            case weightRecords
            case representativeWeights
        }
    }

    struct InputRecord: Decodable {
        let weightRecord: WeightRecord

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let identifier = try container.decode(String.self, forKey: .timeZone)
            guard let timeZone = TimeZone(identifier: identifier) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .timeZone, in: container,
                    debugDescription: "知らないタイムゾーン: \(identifier)")
            }
            weightRecord = WeightRecord(
                id: try container.decode(UUID.self, forKey: .id),
                kilograms: try container.decode(Double.self, forKey: .weightKg),
                instant: try container.decode(Date.self, forKey: .measuredAt),
                timeZone: timeZone,
                inputSource: .manual,
                version: 1
            )
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case measuredAt
            case timeZone
            case weightKg
        }
    }

    struct Expected: Decodable, Equatable, Sendable {
        let day: CalendarDay
        let weightRecordId: UUID
        let kilograms: Double

        init(day: CalendarDay, weightRecordId: UUID, kilograms: Double) {
            self.day = day
            self.weightRecordId = weightRecordId
            self.kilograms = kilograms
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let text = try container.decode(String.self, forKey: .calendarDay)
            guard let day = CalendarDay(yearMonthDay: text) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .calendarDay, in: container,
                    debugDescription: "YYYY-MM-DD の形でない: \(text)")
            }
            self.day = day
            weightRecordId = try container.decode(UUID.self, forKey: .weightRecordId)
            kilograms = try container.decode(Double.self, forKey: .weightKg)
        }

        private enum CodingKeys: String, CodingKey {
            case calendarDay
            case weightRecordId
            case weightKg
        }
    }
}
