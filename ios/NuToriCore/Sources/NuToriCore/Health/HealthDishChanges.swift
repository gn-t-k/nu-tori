import Foundation

/// キャッシュの食事・料理・材料と、書いた料理の控えから出した、ヘルスケアに書く料理と消す料理
struct HealthDishChanges {
    /// ヘルスケアに書いてあるが、料理か親の食事がキャッシュから無くなったか、
    /// 推定し直しが通らず材料が無くなった料理の ID（ID の順）
    let writtenDishIdsToDelete: [UUID]
    /// 量と今の材料があり、推定し直しを待っていない料理で、まだ書いていないか、書いた版より新しいもの（食事の時刻、並び順の順）。
    /// 食事がまだ届いていない料理は入れない。食事の推定の状態は見ない（推定できなかった食事に足した料理も、通れば書く）
    let dishesToWrite: [DishToWrite]

    init(store: any RecordCacheReading & HealthDishWriteStoring) async throws {
        let dishes = try await store.dishes()
        let written = try await store.dishVersionsWrittenToHealth()
        let statuses = try await store.dishEstimationStatuses()
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
                return mealsById[dish.mealId] == nil || ingredientsByDish[dishId] == nil
            }
            .sorted { $0.uuidString < $1.uuidString }
        dishesToWrite =
            dishes
            .compactMap { dish -> (dish: Dish, meal: Meal)? in
                guard let meal = mealsById[dish.mealId],
                    dish.quantity != nil,
                    ingredientsByDish[dish.id] != nil,
                    !Self.awaitsEstimation(statuses[dish.id]),
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
                DishToWrite(
                    contents: DishContents(
                        dish: $0.dish, ingredientsInAnyOrder: ingredientsByDish[$0.dish.id] ?? [],
                        progress: .settled),
                    meal: $0.meal)
            }
    }

    /// 推定し直しを待つあいだは、前に書いた栄養を残して書き直さない
    private static func awaitsEstimation(_ status: DishEstimationStatus?) -> Bool {
        switch status {
        case .estimating, .deferredToNextDay: true
        case .estimated, .noDishes, .failed, nil: false
        }
    }

    /// 書く料理と、時刻を取る親の食事
    struct DishToWrite {
        let contents: DishContents
        let meal: Meal
    }
}
