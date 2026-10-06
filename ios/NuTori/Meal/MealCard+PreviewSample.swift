#if DEBUG
    import Foundation
    import NuToriCore

    extension MealCard {
        /// プレビューの見本の、推定できた食事。親子丼（成分表と推定の材料）と味噌汁（栄養成分表示と、
        /// たんぱく質が「不明」の推定の材料）の2品で、P は「以上」になる
        static func sampleEstimated(_ meal: Meal, recordedOnThisDevice: Bool = true) -> MealCard {
            let oyakodon = Dish(
                id: UUID(), mealId: meal.id, name: "親子丼",
                quantity: Dish.Quantity(value: 1, unit: "杯", source: .estimated),
                positionInMeal: 0, version: 1)
            let misoSoup = Dish(
                id: UUID(), mealId: meal.id, name: "味噌汁",
                quantity: Dish.Quantity(value: 1, unit: "杯", source: .estimated),
                positionInMeal: 1, version: 1)
            return MealCard(
                meal: meal,
                status: .estimated,
                recordedOnThisDevice: recordedOnThisDevice,
                dishes: [oyakodon, misoSoup],
                ingredients: [
                    sampleIngredient(
                        oyakodon, 0, "ご飯", 200, "g", .foodComposition(foodNumber: "01088"),
                        kcal: 156, protein: 2.5, fat: 0.3, carbohydrate: 37.1),
                    sampleIngredient(
                        oyakodon, 1, "鶏もも肉", 80, "g", .foodComposition(foodNumber: "11221"),
                        kcal: 190, protein: 16.6, fat: 14.2, carbohydrate: 0),
                    sampleIngredient(
                        oyakodon, 2, "卵", 1, "個", .foodComposition(foodNumber: "12004"),
                        edibleGramsPerUnit: 50, kcal: 142, protein: 12.2, fat: 10.2,
                        carbohydrate: 0.4),
                    sampleIngredient(
                        oyakodon, 3, "割り下", 30, "ml", .estimated,
                        kcal: 110, protein: 2.0, fat: 0, carbohydrate: 22),
                    sampleIngredient(
                        misoSoup, 0, "味噌汁の素", 1, "袋", .nutritionLabel(basisGrams: 18),
                        edibleGramsPerUnit: 18, kcal: 35, protein: 2.2, fat: 1.1, carbohydrate: 3.8
                    ),
                    sampleIngredient(
                        misoSoup, 1, "わかめ", 2, "g", .estimated,
                        kcal: 20, protein: nil, fat: 0.4, carbohydrate: 5.6),
                ]
            )
        }

        /// プレビューの見本の、kcal はあるが P・F・C がすべて 0 の食事（ブラックコーヒー）
        static func sampleBlackCoffee(_ meal: Meal) -> MealCard {
            let coffee = Dish(
                id: UUID(), mealId: meal.id, name: "ブラックコーヒー",
                quantity: Dish.Quantity(value: 1, unit: "杯", source: .estimated),
                positionInMeal: 0, version: 1)
            return MealCard(
                meal: meal,
                status: .estimated,
                recordedOnThisDevice: true,
                dishes: [coffee],
                ingredients: [
                    sampleIngredient(
                        coffee, 0, "コーヒー", 150, "ml", .estimated,
                        kcal: 4, protein: 0, fat: 0, carbohydrate: 0)
                ]
            )
        }

        /// 値は基準の g（成分表と推定は 100 g、栄養成分表示は表示の単位）あたり。nil は「不明」
        private static func sampleIngredient(
            _ dish: Dish, _ position: Int, _ name: String, _ quantity: Double, _ unit: String,
            _ source: NutrientSource, edibleGramsPerUnit: Double = 1, kcal: Double,
            protein: Double?, fat: Double, carbohydrate: Double
        ) -> Ingredient {
            var nutrients: [Nutrient: Double] = [
                .energyKcal: kcal, .fatG: fat, .carbohydrateG: carbohydrate,
            ]
            nutrients[.proteinG] = protein
            return Ingredient(
                id: UUID(), dishId: dish.id, name: name, quantity: quantity,
                quantitySource: .estimated, unit: unit,
                edibleGramsPerUnit: edibleGramsPerUnit, positionInDish: position,
                nutrientSource: source, nutrients: nutrients)
        }
    }
#endif
