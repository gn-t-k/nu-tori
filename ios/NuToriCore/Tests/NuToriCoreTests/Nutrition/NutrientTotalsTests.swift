import Foundation
import NuToriCore
import Testing

@Suite("栄養の合計")
struct NutrientTotalsTests {
    // swiftlint:disable:next no_parameterized_test
    @Test(
        "材料の合計は、値の分かる材料の分を足し、不明が混じれば以上、すべて不明なら不明になること",
        arguments: try SharedTestCases.decode(
            [SharedCase].self, fromFileNamed: "nutrient-totals.test-cases.json")
    )
    func totalsOfIngredients(testCase: SharedCase) {
        let totals = NutrientTotals(ingredients: testCase.ingredients)

        #expect(
            Dictionary(uniqueKeysWithValues: testCase.totals.keys.map { ($0, totals[$0]) })
                == testCase.totals)
    }

    @Suite("合計どうしを足すとき")
    struct Combining {
        static let known = NutrientTotals(ingredients: [.fixture(nutrients: [.fiberG: 10])])
        static let partial = NutrientTotals(ingredients: [
            .fixture(nutrients: [.fiberG: 5]), .fixture(nutrients: [:]),
        ])
        static let unknown = NutrientTotals(ingredients: [.fixture(nutrients: [:])])

        @Suite("分かる合計どうし")
        struct KnownPlusKnown {
            let totals = NutrientTotals(combining: [Combining.known, Combining.known])

            @Test("足した値になること")
            func sums() {
                #expect(totals[.fiberG] == .exactly(20))
            }
        }

        @Suite("「以上」の合計が混じるとき")
        struct WithAtLeast {
            let totals = NutrientTotals(combining: [Combining.known, Combining.partial])
            let flat = NutrientTotals(ingredients: [
                .fixture(nutrients: [.fiberG: 10]), .fixture(nutrients: [.fiberG: 5]),
                .fixture(nutrients: [:]),
            ])

            @Test("「以上」になること")
            func isAtLeast() {
                #expect(totals[.fiberG] == .atLeast(15))
            }

            @Test("材料から直に出した合計と同じになること")
            func isSameAsFlat() {
                #expect(totals == flat)
            }
        }

        @Suite("不明の合計が分かる合計と混じるとき")
        struct UnknownMixedWithKnown {
            let totals = NutrientTotals(combining: [Combining.unknown, Combining.known])

            @Test("「以上」になること")
            func isAtLeast() {
                #expect(totals[.fiberG] == .atLeast(10))
            }
        }

        @Suite("不明の合計だけのとき")
        struct UnknownOnly {
            let totals = NutrientTotals(combining: [Combining.unknown, Combining.unknown])

            @Test("不明のままになること")
            func isUnknown() {
                #expect(totals[.fiberG] == .unknown)
            }
        }
    }

    struct SharedCase: Decodable, Sendable, CustomTestStringConvertible {
        let name: String
        let ingredients: [Ingredient]
        let totals: [Nutrient: NutrientAmount]

        var testDescription: String { name }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            ingredients = try container.decode([SharedIngredient].self, forKey: .ingredients).map(
                \.ingredient)
            totals = try Self.nutrientKeyed(
                container.decode([String: SharedAmount].self, forKey: .totals).mapValues(\.amount))
        }

        static func nutrientKeyed<Value>(_ values: [String: Value]) throws -> [Nutrient: Value] {
            try Dictionary(
                uniqueKeysWithValues: values.map { name, value in
                    guard let nutrient = Nutrient(rawValue: name) else {
                        throw DecodingError.dataCorrupted(
                            .init(codingPath: [], debugDescription: "知らない栄養: \(name)"))
                    }
                    return (nutrient, value)
                })
        }

        private enum CodingKeys: String, CodingKey {
            case name
            case ingredients
            case totals
        }
    }

    struct SharedIngredient: Decodable {
        let ingredient: Ingredient

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let source = try container.decode(SharedNutrientSource.self, forKey: .nutrientSource)
            ingredient = .fixture(
                quantity: try container.decode(Double.self, forKey: .quantity),
                edibleGramsPerUnit: try container.decode(Double.self, forKey: .edibleGramsPerUnit),
                nutrientSource: source.nutrientSource,
                nutrients: try SharedCase.nutrientKeyed(
                    container.decode([String: Double].self, forKey: .nutrients)))
        }

        private enum CodingKeys: String, CodingKey {
            case quantity
            case edibleGramsPerUnit
            case nutrientSource
            case nutrients
        }
    }

    struct SharedNutrientSource: Decodable {
        let nutrientSource: NutrientSource

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "nutrition_label":
                nutrientSource = .nutritionLabel(
                    basisGrams: try container.decode(Double.self, forKey: .labelBasisGrams))
            case "food_composition":
                nutrientSource = .foodComposition(
                    foodNumber: try container.decode(String.self, forKey: .foodNumber))
            case "estimated":
                nutrientSource = .estimated
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type, in: container, debugDescription: "知らない出どころ: \(type)")
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type
            case labelBasisGrams
            case foodNumber
        }
    }

    struct SharedAmount: Decodable {
        let amount: NutrientAmount

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "exactly": amount = .exactly(try container.decode(Double.self, forKey: .value))
            case "at_least": amount = .atLeast(try container.decode(Double.self, forKey: .value))
            case "unknown": amount = .unknown
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type, in: container, debugDescription: "知らない合計の形: \(type)")
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type
            case value
        }
    }
}
