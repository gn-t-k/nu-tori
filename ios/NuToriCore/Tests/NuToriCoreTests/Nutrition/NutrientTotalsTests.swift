import Foundation
import NuToriCore
import Testing

@Suite("栄養の合計")
struct NutrientTotalsTests {
    @Suite("材料の栄養の値")
    struct IngredientAmount {
        @Test("成分表の材料は、可食部 100 g あたりの値に量と可食部の g を掛けて 100 で割ること")
        func foodCompositionIsPer100Grams() {
            let ingredient = Ingredient.fixture(
                quantity: 200, edibleGramsPerUnit: 1,
                nutrientSource: .foodComposition(foodNumber: "11225"),
                nutrients: [.energyKcal: 204])

            #expect(ingredient.amount(of: .energyKcal) == 408)
        }

        @Test("1単位あたりの可食部の g を掛けること（卵 2 個、1 個の可食部 50 g）")
        func multipliesByEdibleGramsPerUnit() {
            let ingredient = Ingredient.fixture(
                name: "卵", quantity: 2, unit: "個", edibleGramsPerUnit: 50,
                nutrientSource: .foodComposition(foodNumber: "12004"),
                nutrients: [.energyKcal: 142])

            #expect(ingredient.amount(of: .energyKcal) == 142)
        }

        @Test("栄養成分表示の材料は、表示の単位あたりの g で割ること（250 g あたり 40 kcal の 500 g）")
        func nutritionLabelIsPerLabelBasis() {
            let ingredient = Ingredient.fixture(
                name: "緑茶", quantity: 1, unit: "本", edibleGramsPerUnit: 500,
                nutrientSource: .nutritionLabel(basisGrams: 250),
                nutrients: [.energyKcal: 40])

            #expect(ingredient.amount(of: .energyKcal) == 80)
        }

        @Test("AI の推定の材料は、可食部 100 g あたりとして割ること")
        func estimatedIsPer100Grams() {
            let ingredient = Ingredient.fixture(
                name: "ご飯", quantity: 1, unit: "杯", edibleGramsPerUnit: 150,
                nutrientSource: .estimated, nutrients: [.energyKcal: 156])

            #expect(ingredient.amount(of: .energyKcal) == 234)
        }

        @Test("値を持たない項目は不明（0 にしない）")
        func missingNutrientIsUnknown() {
            let ingredient = Ingredient.fixture(nutrients: [.energyKcal: 204])

            #expect(ingredient.amount(of: .fiberG) == nil)
        }

        @Test("値が 0 の項目は 0 で、不明にしないこと")
        func zeroIsAValue() {
            let ingredient = Ingredient.fixture(nutrients: [.fiberG: 0])

            #expect(ingredient.amount(of: .fiberG) == 0)
        }
    }

    @Suite("材料の合計")
    struct OfIngredients {
        @Test("すべての材料の値が分かる栄養は、足した値になること")
        func sumsKnownValues() {
            let totals = NutrientTotals(ingredients: [
                .fixture(quantity: 100, nutrients: [.energyKcal: 200, .proteinG: 20]),
                .fixture(quantity: 50, nutrients: [.energyKcal: 100, .proteinG: 4]),
            ])

            #expect(totals[.energyKcal] == .exactly(250))
            #expect(totals[.proteinG] == .exactly(22))
        }

        @Test("不明の材料が混じる栄養は、分かる分だけを足して「以上」になること")
        func unknownMixedIsAtLeast() {
            let totals = NutrientTotals(ingredients: [
                .fixture(quantity: 100, nutrients: [.energyKcal: 200, .fiberG: 3]),
                .fixture(quantity: 100, nutrients: [.energyKcal: 100]),
            ])

            #expect(totals[.energyKcal] == .exactly(300))
            #expect(totals[.fiberG] == .atLeast(3))
        }

        @Test("すべての材料が不明の栄養だけ、不明になること")
        func allUnknownIsUnknown() {
            let totals = NutrientTotals(ingredients: [
                .fixture(nutrients: [.energyKcal: 200]),
                .fixture(nutrients: [.energyKcal: 100]),
            ])

            #expect(totals[.fiberG] == .unknown)
        }

        @Test("値が 0 の材料と不明の材料が混じると、0 以上になること")
        func zeroAndUnknownMixed() {
            let totals = NutrientTotals(ingredients: [
                .fixture(nutrients: [.fiberG: 0]),
                .fixture(nutrients: [:]),
            ])

            #expect(totals[.fiberG] == .atLeast(0))
        }

        @Test("kcal は材料の kcal の和で、たんぱく質・脂質・炭水化物から出し直さないこと")
        func energyIsSumOfIngredientEnergy() {
            // 4×10 + 9×5 + 4×20 = 165 kcal に当たる P・F・C だが、材料の kcal は 100（アルコールの分などで食い違う）
            let totals = NutrientTotals(ingredients: [
                .fixture(
                    quantity: 100,
                    nutrients: [.energyKcal: 100, .proteinG: 10, .fatG: 5, .carbohydrateG: 20])
            ])

            #expect(totals[.energyKcal] == .exactly(100))
        }

        @Test("材料が無いときは、どの栄養も 0 になること")
        func noIngredientsIsZero() {
            let totals = NutrientTotals(ingredients: [])

            #expect(totals[.energyKcal] == .exactly(0))
            #expect(totals[.proteinG] == .exactly(0))
        }
    }

    @Suite("合計どうしを足すとき")
    struct Combining {
        let known = NutrientTotals(ingredients: [.fixture(nutrients: [.fiberG: 10])])
        let partial = NutrientTotals(ingredients: [
            .fixture(nutrients: [.fiberG: 5]), .fixture(nutrients: [:]),
        ])
        let unknown = NutrientTotals(ingredients: [.fixture(nutrients: [:])])

        @Test("分かる合計どうしは、足した値になること")
        func knownPlusKnown() {
            #expect(NutrientTotals(combining: [known, known])[.fiberG] == .exactly(20))
        }

        @Test("「以上」の合計が混じれば、「以上」になること")
        func atLeastPropagates() {
            #expect(NutrientTotals(combining: [known, partial])[.fiberG] == .atLeast(15))
        }

        @Test("不明の合計が分かる合計と混じれば、「以上」になること")
        func unknownMixedWithKnown() {
            #expect(NutrientTotals(combining: [unknown, known])[.fiberG] == .atLeast(10))
        }

        @Test("不明の合計だけなら、不明のままになること")
        func unknownOnly() {
            #expect(NutrientTotals(combining: [unknown, unknown])[.fiberG] == .unknown)
        }

        @Test("材料から直に出した合計と同じになること")
        func sameAsFlat() {
            let flat = NutrientTotals(ingredients: [
                .fixture(nutrients: [.fiberG: 10]), .fixture(nutrients: [.fiberG: 5]),
                .fixture(nutrients: [:]),
            ])

            #expect(NutrientTotals(combining: [known, partial]) == flat)
        }
    }
}
