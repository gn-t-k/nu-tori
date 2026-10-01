import Foundation
import NuToriCore
import Testing

@Suite("栄養の項目")
struct NutrientTests {
    @Test("shared/nutrients.json の項目と単位が、過不足なく端末の項目になっていること")
    func matchesSharedJSON() throws {
        let shared = try SharedTestCases.decode([String: Item].self, fromFileNamed: "nutrients.json")

        let device = Dictionary(
            uniqueKeysWithValues: Nutrient.allCases.map { ($0.rawValue, $0.unit) })

        #expect(device == shared.mapValues(\.unit))
    }

    @Test("名前から項目を引け、知らない名前は引けないこと")
    func looksUpByName() {
        #expect(Nutrient(rawValue: "protein_g") == .proteinG)
        #expect(Nutrient(rawValue: "energy_kcal") == .energyKcal)
        #expect(Nutrient(rawValue: "vitamin_b12_ug") == .vitaminB12Ug)
        #expect(Nutrient(rawValue: "future_nutrient_g") == nil)
    }

    private struct Item: Decodable {
        let unit: String
    }
}
