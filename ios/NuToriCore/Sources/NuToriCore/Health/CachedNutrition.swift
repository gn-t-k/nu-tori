import Foundation

/// ヘルスケアに栄養を書く・消すかを決めるための、キャッシュの食事・料理・材料と、書いた料理の控え
struct CachedNutrition {
    /// ヘルスケアに書いてあるが、料理か親の食事がキャッシュから無くなった料理の ID（ID の順）
    let writtenDishIdsToDelete: [UUID]
    /// 推定できた食事の料理で、まだ書いていないか、書いた版より新しいもの（食事の時刻、並び順の順）。
    /// 食事がまだ届いていない料理と、推定できていない食事の料理は入れない
    let dishesToWrite: [DishContents]

    init(store: any RecordCacheReading & HealthDishWriteStoring) async throws {
        let dishes = try await store.dishes()
        let written = try await store.dishVersionsWrittenToHealth()
        let statuses = try await store.mealEstimationStatuses()
        let ingredients = try await store.ingredients()
        let meals = try await store.meals()
        let mealsById = Dictionary(
            meals.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let dishesById = Dictionary(
            dishes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ingredientsByDish = Dictionary(grouping: ingredients, by: \.dishId)

        writtenDishIdsToDelete = written.keys
            .filter { dishId in
                guard let dish = dishesById[dishId] else { return true }
                return mealsById[dish.mealId] == nil
            }
            .sorted { $0.uuidString < $1.uuidString }
        dishesToWrite =
            dishes
            .compactMap { dish -> (dish: Dish, meal: Meal)? in
                guard let meal = mealsById[dish.mealId],
                    statuses[dish.mealId] == .estimated,
                    dish.version > (written[dish.id] ?? 0)
                else {
                    return nil
                }
                return (dish, meal)
            }
            .sorted {
                ($0.meal.eatenAt, $0.dish.positionInMeal, $0.dish.id.uuidString)
                    < ($1.meal.eatenAt, $1.dish.positionInMeal, $1.dish.id.uuidString)
            }
            .map {
                DishContents(
                    dish: $0.dish, ingredientsInAnyOrder: ingredientsByDish[$0.dish.id] ?? [])
            }
        self.mealsById = mealsById
    }

    func meal(of dish: Dish) -> Meal? {
        mealsById[dish.mealId]
    }

    private let mealsById: [UUID: Meal]
}
