#if DEBUG
    import Foundation
    import NuToriAPI

    /// 見本の人（`UITestLaunch.listingSampleScenario(_:)`）の食事の料理。作り物で、開発者の食事ではない（ADR-0010）。
    ///
    /// 料理・材料・量は LP の版 a の見本の食事（`site/src/pages/landing-a/landing-a-examples.json`）と同じにする。
    /// 栄養の値は、その JSON を書き出す `server/scripts/print-landing-a-examples.ts` が引く成分表の食品番号の値（`server/src/domain/food-composition/food-composition-table.json` の可食部 100 g あたり）。
    /// 画面に出す kcal と P・F・C の4つだけを写す。割り下だけは、同じスクリプトが AI の推定とした値。
    /// 料理の量は JSON に無いので、1皿・1杯・1個にする。例の食事が変わって JSON を書き出し直したら、ここも写し直す
    nonisolated struct ListingSampleDish: Sendable {
        let name: String
        let quantityValue: Double
        let quantityUnit: String
        let ingredients: [Ingredient]

        struct Ingredient: Sendable {
            let name: String
            let quantity: Double
            let unit: String
            let edibleGramsPerUnit: Double
            let source: SyncedIngredient.NutrientSource
            let nutrients: [String: Double]
        }

        /// 318 kcal
        static let onigiri = ListingSampleDish(
            name: "おにぎり", quantityValue: 2, quantityUnit: "個",
            ingredients: [
                rice(grams: 200),
                .init(
                    name: "焼きのり", quantity: 2, unit: "g", edibleGramsPerUnit: 1,
                    source: .foodComposition(foodNumber: "09004"),
                    nutrients: nutrients(297, 32, 2.2, 1.7)),
            ])

        /// 568 kcal
        static let oyakodon = ListingSampleDish(
            name: "親子丼", quantityValue: 1, quantityUnit: "杯",
            ingredients: [
                rice(grams: 200),
                .init(
                    name: "鶏もも肉", quantity: 80, unit: "g", edibleGramsPerUnit: 1,
                    source: .foodComposition(foodNumber: "11221"),
                    nutrients: nutrients(190, 17, 13.5, 0)),
                .init(
                    name: "卵", quantity: 1, unit: "個", edibleGramsPerUnit: 50,
                    source: .foodComposition(foodNumber: "12004"),
                    nutrients: nutrients(142, 11.3, 9.3, 0.3)),
                .init(
                    name: "割り下", quantity: 30, unit: "ml", edibleGramsPerUnit: 1,
                    source: .estimated, nutrients: nutrients(110, 2, 0, 22)),
            ])

        /// 554 kcal
        static let curry = ListingSampleDish(
            name: "カレーライス", quantityValue: 1, quantityUnit: "皿",
            ingredients: [
                rice(grams: 200),
                composition("牛肉（かた）", grams: 50, "11060", nutrients(160, 19, 9.3, 0.1)),
                composition("じゃがいも", grams: 50, "02019", nutrients(71, 1.4, 0, 14.6)),
                composition("たまねぎ", grams: 40, "06155", nutrients(30, 0.5, 0, 4.7)),
                composition("にんじん", grams: 20, "06215", nutrients(28, 0.5, 0.1, 5)),
                composition("カレールウ", grams: 20, "17051", nutrients(474, 5.7, 32.8, 35.1)),
                composition("福神漬", grams: 10, "06143", nutrients(137, 2.7, 0.1, 29.4)),
            ])

        /// 252 kcal。LP では書いた食事（「朝はお茶漬けを食べた」）の見本
        static let ochazuke = ListingSampleDish(
            name: "お茶漬け", quantityValue: 1, quantityUnit: "杯",
            ingredients: [
                rice(grams: 150),
                composition("お茶漬けの素", grams: 6, "17125", nutrients(251, 18, 2.7, 27.9)),
                .init(
                    name: "緑茶", quantity: 150, unit: "ml", edibleGramsPerUnit: 1,
                    source: .foodComposition(foodNumber: "16037"),
                    nutrients: nutrients(2, 0.2, 0, 0.3)),
            ])

        /// 推定を終えた食事の料理と材料。`id` は、0 に料理の、1 からは材料の並びの ID を返す
        func changes(mealId: UUID, id: (Int) -> UUID) -> [SyncChange] {
            let dishId = id(0)
            return [
                .dish(
                    SyncedDish(
                        id: dishId, mealId: mealId, name: name,
                        quantity: .init(
                            value: quantityValue, unit: quantityUnit, source: .estimated),
                        positionInMeal: 0, version: 1))
            ]
                + ingredients.enumerated().map { index, ingredient in
                    .ingredient(
                        SyncedIngredient(
                            id: id(index + 1), dishId: dishId, name: ingredient.name,
                            quantity: ingredient.quantity, quantitySource: .estimated,
                            unit: ingredient.unit,
                            edibleGramsPerUnit: ingredient.edibleGramsPerUnit,
                            positionInDish: index, nutrientSource: ingredient.source,
                            nutrients: ingredient.nutrients))
                }
        }

        private static func rice(grams: Double) -> Ingredient {
            composition("ご飯", grams: grams, "01088", nutrients(156, 2, 0.2, 34.6))
        }

        private static func composition(
            _ name: String, grams: Double, _ foodNumber: String, _ nutrients: [String: Double]
        ) -> Ingredient {
            Ingredient(
                name: name, quantity: grams, unit: "g", edibleGramsPerUnit: 1,
                source: .foodComposition(foodNumber: foodNumber), nutrients: nutrients)
        }

        private static func nutrients(
            _ energy: Double, _ protein: Double, _ fat: Double, _ carbohydrate: Double
        ) -> [String: Double] {
            [
                "energy_kcal": energy, "protein_g": protein, "fat_g": fat,
                "carbohydrate_g": carbohydrate,
            ]
        }
    }
#endif
