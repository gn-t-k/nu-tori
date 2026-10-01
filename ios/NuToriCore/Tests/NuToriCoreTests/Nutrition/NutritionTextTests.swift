import Foundation
import NuToriCore
import Testing

@Suite("栄養と量の文言")
struct NutritionTextTests {
    @Suite("栄養の合計の値")
    struct Amount {
        @Test("kcal を、数との間を空けて整数に丸めること")
        func roundsKilocalories() {
            #expect(NutritionText.amount(.exactly(510.4), of: .energyKcal) == "510 kcal")
        }

        @Test("g を整数に丸めること")
        func roundsGrams() {
            #expect(NutritionText.amount(.exactly(31.5), of: .proteinG) == "32 g")
            #expect(NutritionText.amount(.exactly(0.2), of: .fatG) == "0 g")
        }

        @Test("千を超える値を3桁ごとに区切ること")
        func groupsThousands() {
            #expect(NutritionText.amount(.exactly(1850), of: .energyKcal) == "1,850 kcal")
            #expect(NutritionText.amount(.exactly(12_345.6), of: .energyKcal) == "12,346 kcal")
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
        @Test("英字の単位は、数との間を空けること")
        func spacesLatinUnit() {
            #expect(NutritionText.quantity(110, unit: "g") == "110 g")
            #expect(NutritionText.quantity(3, unit: "µg") == "3 µg")
        }

        @Test("日本語の単位は、数に続けること")
        func joinsJapaneseUnit() {
            #expect(NutritionText.quantity(2, unit: "個") == "2個")
        }

        @Test("小数は1桁まで出し、端数が無ければ整数にすること")
        func roundsToTenths() {
            #expect(NutritionText.quantity(1.5, unit: "杯") == "1.5杯")
            #expect(NutritionText.quantity(0.25, unit: "ml") == "0.3 ml")
            #expect(NutritionText.quantity(200.04, unit: "ml") == "200 ml")
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
