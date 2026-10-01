import Foundation
import NuToriCore
import Testing

@Suite("材料の栄養の値")
struct IngredientTests {
    @Suite("成分表の材料")
    struct FoodComposition {
        let ingredient: Ingredient

        init() {
            ingredient = .fixture(
                quantity: 200, edibleGramsPerUnit: 1,
                nutrientSource: .foodComposition(foodNumber: "11225"),
                nutrients: [.energyKcal: 204])
        }

        @Test("可食部 100 g あたりの値に、量と可食部の g を掛けて 100 で割ること")
        func isPer100Grams() {
            #expect(ingredient.amount(of: .energyKcal) == 408)
        }
    }

    @Suite("卵 2 個（1 個の可食部 50 g）の材料")
    struct CountedInUnits {
        let ingredient: Ingredient

        init() {
            ingredient = .fixture(
                name: "卵", quantity: 2, unit: "個", edibleGramsPerUnit: 50,
                nutrientSource: .foodComposition(foodNumber: "12004"),
                nutrients: [.energyKcal: 142])
        }

        @Test("1単位あたりの可食部の g を掛けること")
        func multipliesByEdibleGramsPerUnit() {
            #expect(ingredient.amount(of: .energyKcal) == 142)
        }
    }

    @Suite("栄養成分表示が 250 g あたり 40 kcal の材料を 500 g 食べたとき")
    struct NutritionLabel {
        let ingredient: Ingredient

        init() {
            ingredient = .fixture(
                name: "緑茶", quantity: 1, unit: "本", edibleGramsPerUnit: 500,
                nutrientSource: .nutritionLabel(basisGrams: 250),
                nutrients: [.energyKcal: 40])
        }

        @Test("表示の単位あたりの g で割り、80 kcal と数えること")
        func isPerLabelBasis() {
            #expect(ingredient.amount(of: .energyKcal) == 80)
        }
    }

    @Suite("AI の推定の材料")
    struct Estimated {
        let ingredient: Ingredient

        init() {
            ingredient = .fixture(
                name: "ご飯", quantity: 1, unit: "杯", edibleGramsPerUnit: 150,
                nutrientSource: .estimated, nutrients: [.energyKcal: 156])
        }

        @Test("可食部 100 g あたりとして割ること")
        func isPer100Grams() {
            #expect(ingredient.amount(of: .energyKcal) == 234)
        }
    }

    @Suite("値を持たない項目")
    struct MissingNutrient {
        let ingredient: Ingredient

        init() {
            ingredient = .fixture(nutrients: [.energyKcal: 204])
        }

        @Test("0 にせず不明にすること")
        func isUnknown() {
            #expect(ingredient.amount(of: .fiberG) == nil)
        }
    }

    @Suite("値が 0 の項目")
    struct ZeroNutrient {
        let ingredient: Ingredient

        init() {
            ingredient = .fixture(nutrients: [.fiberG: 0])
        }

        @Test("0 で、不明にしないこと")
        func isZero() {
            #expect(ingredient.amount(of: .fiberG) == 0)
        }
    }
}
