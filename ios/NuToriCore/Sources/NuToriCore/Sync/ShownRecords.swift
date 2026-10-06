public import Foundation

/// 受け付けなかった書き込みの1行に添える、端末で見せていた記録。サーバーの今の値を当てる前のキャッシュから読む
/// （直そうとした記録が消えていても、端末で見せていた名前と食事の時刻で行を出すため）
public struct ShownRecords: Sendable {
    public let meals: [UUID: Meal]
    public let dishes: [UUID: Dish]
    public let ingredients: [UUID: Ingredient]

    public static let none = ShownRecords(meals: [], dishes: [], ingredients: [])

    public init(meals: [Meal], dishes: [Dish], ingredients: [Ingredient]) {
        self.meals = Dictionary(meals.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        self.dishes = Dictionary(dishes.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        self.ingredients = Dictionary(
            ingredients.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    }

    /// 端末で見せていた料理と、その食事
    func dishPlace(of dishId: UUID) -> (meal: Meal, place: RejectedMealLine.DishPlace)? {
        guard let dish = dishes[dishId], let meal = meals[dish.mealId] else { return nil }
        return (
            meal,
            RejectedMealLine.DishPlace(
                id: dish.id, name: dish.name, positionInMeal: dish.positionInMeal)
        )
    }

    /// 端末で見せていた材料と、その料理と食事
    func ingredientPlace(of ingredientId: UUID)
        -> (meal: Meal, place: RejectedMealLine.IngredientPlace)?
    {
        guard let ingredient = ingredients[ingredientId],
            let (meal, dish) = dishPlace(of: ingredient.dishId)
        else { return nil }
        return (
            meal,
            RejectedMealLine.IngredientPlace(
                id: ingredient.id, name: ingredient.name, unit: ingredient.unit,
                positionInDish: ingredient.positionInDish, dish: dish)
        )
    }
}
