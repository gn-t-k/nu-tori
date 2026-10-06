import Foundation
import NuToriCore

extension MealCard {
    /// 時刻は ISO 8601 の時刻。`nutrients` を渡すと、材料1つ（量 100 g・可食部 1 g・成分表）の料理を1つ持つ
    /// 食事にする。材料の栄養の値が、そのまま食事の合計になる
    static func fixture(
        eatenAt: String = "2026-09-24T12:10:00+09:00",
        sentAt: String? = nil,
        status: MealEstimationStatus?,
        nutrients: [Nutrient: Double]? = nil,
        recordedOnThisDevice: Bool = true
    ) throws -> MealCard {
        let meal = try Meal.fixture(eatenAt: eatenAt, sentAt: sentAt ?? eatenAt)
        guard let nutrients else {
            return MealCard(
                meal: meal, status: status, recordedOnThisDevice: recordedOnThisDevice,
                dishes: [], ingredients: [], dishEstimationStatuses: [:], unsentDishIds: [])
        }
        let dish = Dish.fixture(mealId: meal.id)
        return MealCard(
            meal: meal, status: status, recordedOnThisDevice: recordedOnThisDevice,
            dishes: [dish],
            ingredients: [.fixture(dishId: dish.id, nutrients: nutrients)],
            dishEstimationStatuses: [:], unsentDishIds: [])
    }
}
