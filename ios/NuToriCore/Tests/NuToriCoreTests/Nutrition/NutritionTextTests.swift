import Foundation
import NuToriCore
import Testing

@Suite("栄養と量の文言")
struct NutritionTextTests {
    @Suite("栄養の合計の値")
    struct Amount {
        @Test(
            "数と単位の間を空け、整数に丸めること",
            arguments: [
                (NutrientAmount.exactly(510.4), Nutrient.energyKcal, "510 kcal"),
                (.exactly(31.5), .proteinG, "32 g"),
                (.exactly(0.2), .fatG, "0 g"),
                (.exactly(1850), .energyKcal, "1,850 kcal"),
                (.exactly(12_345.6), .energyKcal, "12,346 kcal"),
            ])
        func roundsToWhole(amount: NutrientAmount, nutrient: Nutrient, text: String) {
            #expect(NutritionText.amount(amount, of: nutrient) == text)
        }

        @Test("「不明」の材料が混じる値には「以上」を付けること")
        func marksLowerBound() {
            #expect(NutritionText.amount(.atLeast(78), of: .carbohydrateG) == "78 g 以上")
        }

        @Test("すべての材料が「不明」なら「—」にすること")
        func dashesUnknown() {
            #expect(NutritionText.amount(.unknown, of: .proteinG) == "—")
        }

        @Test("数だけを出すときは、単位と「以上」を付けないこと")
        func numberOnly() {
            #expect(NutritionText.number(.atLeast(1121.2), of: .energyKcal) == "1,121")
            #expect(NutritionText.number(.unknown, of: .energyKcal) == "—")
        }
    }

    @Suite("料理と材料の量")
    struct Quantity {
        @Test(
            "英字の単位は数との間を空け、日本語の単位は続けること",
            arguments: [
                (110.0, "g", "110 g"),
                (2.0, "個", "2個"),
                (1.5, "杯", "1.5杯"),
                (0.25, "ml", "0.3 ml"),
                (200.04, "ml", "200 ml"),
                (3.0, "µg", "3 µg"),
            ])
        func formatsQuantity(quantity: Double, unit: String, text: String) {
            #expect(NutritionText.quantity(quantity, unit: unit) == text)
        }
    }

    @Suite("栄養の出どころの1行")
    struct SourceLine {
        @Test("2種類以上なら、栄養成分表示・成分表・推定の順に数を添えること")
        func listsCounts() throws {
            let line = try #require(
                Self.line(sources: [
                    .estimated, .foodComposition(foodNumber: "01088"),
                    .nutritionLabel(basisGrams: 30), .foodComposition(foodNumber: "11220"),
                ]))

            #expect(NutritionText.sourceLine(line) == "栄養の出どころ: 栄養成分表示 1・成分表 2・推定 1")
        }

        @Test("1種類だけなら数を書かないこと")
        func omitsCountForSingleKind() throws {
            let line = try #require(
                Self.line(sources: [
                    .foodComposition(foodNumber: "01088"), .foodComposition(foodNumber: "11220"),
                ]))

            #expect(NutritionText.sourceLine(line) == "栄養の出どころ: 成分表")
        }

        static func line(sources: [NutrientSource]) -> NutrientSourceLine? {
            let dish = Dish.fixture()
            return MealContents(
                mealId: dish.mealId, dishes: [dish],
                ingredients: sources.map { .fixture(dishId: dish.id, nutrientSource: $0) }
            ).nutrientSourceLine
        }
    }
}
