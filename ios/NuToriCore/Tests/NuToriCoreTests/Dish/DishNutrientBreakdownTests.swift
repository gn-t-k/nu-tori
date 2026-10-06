import Foundation
import NuToriCore
import Testing

@Suite("料理の画面の栄養の内訳")
struct DishNutrientBreakdownTests {
    static func breakdown(_ ingredients: [Ingredient]) -> DishNutrientBreakdown {
        let dish = Dish.fixture()
        return DishNutrientBreakdown(
            DishContents(
                dish: dish,
                ingredients: ingredients.map {
                    .fixture(
                        dishId: dish.id, nutrientSource: $0.nutrientSource, nutrients: $0.nutrients)
                }, progress: .settled))
    }

    static func text(_ breakdown: DishNutrientBreakdown, _ name: String) throws -> String {
        try #require(breakdown.groups.flatMap(\.rows).first { $0.name == name }).text
    }

    @Test("主な栄養・ミネラル・ビタミンの順に、#188 の内訳の画面に出す15項目を並べること")
    func items() {
        let breakdown = Self.breakdown([.fixture()])

        #expect(breakdown.groups.map(\.title) == ["主な栄養", "ミネラル", "ビタミン"])
        #expect(
            breakdown.groups.map { $0.rows.map(\.name) } == [
                ["エネルギー", "たんぱく質", "脂質", "炭水化物", "食物繊維", "食塩相当量"],
                ["カルシウム", "鉄", "カリウム", "マグネシウム"],
                ["ビタミンA", "ビタミンB1", "ビタミンB2", "ビタミンC", "ビタミンD"],
            ])
    }

    @Suite("材料がすべての値を持つとき")
    struct AllKnown {
        let breakdown: DishNutrientBreakdown

        init() {
            breakdown = DishNutrientBreakdownTests.breakdown([
                .fixture(nutrients: [.energyKcal: 150, .proteinG: 2.5, .calciumMg: 3]),
                .fixture(nutrients: [.energyKcal: 239, .proteinG: 3.5, .calciumMg: 9]),
            ])
        }

        @Test("料理の今の材料の値を足すこと")
        func sumsIngredients() throws {
            #expect(try DishNutrientBreakdownTests.text(breakdown, "エネルギー") == "389 kcal")
            #expect(try DishNutrientBreakdownTests.text(breakdown, "たんぱく質") == "6.0 g")
            #expect(try DishNutrientBreakdownTests.text(breakdown, "カルシウム") == "12 mg")
        }
    }

    @Suite("一部の材料だけ分からない栄養と、どの材料でも分からない栄養があるとき")
    struct PartlyUnknown {
        let breakdown: DishNutrientBreakdown

        init() {
            breakdown = DishNutrientBreakdownTests.breakdown([
                .fixture(nutrients: [.energyKcal: 150, .ironMg: 0.4]),
                .fixture(nutrients: [.energyKcal: 50]),
            ])
        }

        @Test("一部の材料だけ分からない栄養は、分かる分に「以上」を付けること")
        func atLeast() throws {
            let iron = try #require(breakdown.groups.flatMap(\.rows).first { $0.name == "鉄" })

            #expect(try DishNutrientBreakdownTests.text(breakdown, "エネルギー") == "200 kcal")
            #expect(iron.text == "0.4 mg 以上")
            #expect(!iron.isUnknown)
        }

        @Test("どの材料でも分からない栄養は「不明」にすること")
        func unknown() throws {
            let vitaminC = try #require(
                breakdown.groups.flatMap(\.rows).first { $0.name == "ビタミンC" })

            #expect(vitaminC.text == "不明")
            #expect(vitaminC.isUnknown)
        }
    }

    @Suite("推定した材料だけの料理のとき")
    struct EstimatedOnly {
        let breakdown: DishNutrientBreakdown

        init() {
            breakdown = DishNutrientBreakdownTests.breakdown([
                .fixture(nutrientSource: .estimated, nutrients: [.energyKcal: 300, .proteinG: 10])
            ])
        }

        @Test("ミネラルとビタミンの行を「不明」で並べること")
        func showsUnknownMineralsAndVitamins() {
            #expect(breakdown.groups[1].rows.allSatisfy { $0.text == "不明" })
            #expect(breakdown.groups[2].rows.allSatisfy { $0.text == "不明" })
        }
    }

    @Suite("値の桁がさまざまなとき")
    struct Digits {
        let breakdown: DishNutrientBreakdown

        init() {
            breakdown = DishNutrientBreakdownTests.breakdown([
                .fixture(nutrients: [
                    .carbohydrateG: 77, .potassiumMg: 120, .vitaminDUg: 1.5, .vitaminB1Mg: 0.06,
                    .vitaminCMg: 0, .vitaminAUg: 45,
                ])
            ])
        }

        @Test("g は小数1桁、mg と µg は 10 以上を整数・1 以上を小数1桁・1 未満を小数2桁まで（末尾の 0 を除く）にし、0 は 0 と書くこと")
        func digits() throws {
            #expect(try DishNutrientBreakdownTests.text(breakdown, "炭水化物") == "77.0 g")
            #expect(try DishNutrientBreakdownTests.text(breakdown, "カリウム") == "120 mg")
            #expect(try DishNutrientBreakdownTests.text(breakdown, "ビタミンD") == "1.5 µg")
            #expect(try DishNutrientBreakdownTests.text(breakdown, "ビタミンB1") == "0.06 mg")
            #expect(try DishNutrientBreakdownTests.text(breakdown, "ビタミンC") == "0 mg")
            #expect(try DishNutrientBreakdownTests.text(breakdown, "ビタミンA") == "45 µg")
        }
    }

    @Test("画面の下に「以上」と「不明」の意味を1回だけ書くこと")
    func note() {
        #expect(
            DishNutrientBreakdown.note
                == "「以上」は、一部の材料の値が分からず、分かる分だけを足した値です。「不明」は、どの材料も値が分からない栄養です。")
    }
}
