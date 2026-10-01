import NuToriCore
import Testing

@Suite("ヘルスケアに書く栄養の種類")
struct HealthNutrientTests {
    @Suite("栄養の項目との対応")
    struct SourceNutrients {
        @Test("水分を除くすべての栄養の項目が、ちょうど1つの種類に対応すること")
        func coversEveryNutrientExceptWaterOnce() {
            let sources = HealthNutrient.allCases.map(\.source)

            #expect(Set(sources) == Set(Nutrient.allCases).subtracting([.waterG]))
            #expect(sources.count == Set(sources).count)
        }

        @Test("食塩相当量をナトリウムに対応させること")
        func mapsSaltToSodium() {
            #expect(HealthNutrient.sodium.source == .saltEquivalentG)
        }

        @Test("書く値の単位が、栄養の項目の単位と同じで、ナトリウムだけ mg であること")
        func unitsMatchNutrientUnits() {
            for nutrient in HealthNutrient.allCases {
                let expected = nutrient == .sodium ? "mg" : nutrient.source.unit
                #expect(nutrient.unit.symbol == expected, "\(nutrient)")
            }
        }
    }
}

extension HealthNutrient.Unit {
    fileprivate var symbol: String {
        switch self {
        case .kilocalorie: "kcal"
        case .gram: "g"
        case .milligram: "mg"
        case .microgram: "µg"
        }
    }
}
