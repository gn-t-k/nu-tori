import Foundation
import NuToriCore
import SwiftData

/// 料理。食事とは別の種類で、食事より先に届くこともあるので、親の食事の ID を値で持つ
@Model
nonisolated final class CachedDish {
    @Attribute(.unique) var dishId: UUID
    var mealId: UUID
    var name: String
    var quantity: Double
    var unit: String
    var positionInMeal: Int
    var version: Int

    init(_ dish: Dish) {
        dishId = dish.id
        mealId = dish.mealId
        name = dish.name
        quantity = dish.quantity
        unit = dish.unit
        positionInMeal = dish.positionInMeal
        version = dish.version
    }

    /// 同じ ID が届き直したときは、その値にそろえる
    func apply(_ dish: Dish) {
        mealId = dish.mealId
        name = dish.name
        quantity = dish.quantity
        unit = dish.unit
        positionInMeal = dish.positionInMeal
        version = dish.version
    }

    func dish() -> Dish {
        Dish(
            id: dishId,
            mealId: mealId,
            name: name,
            quantity: quantity,
            unit: unit,
            positionInMeal: positionInMeal,
            version: version
        )
    }
}

/// キャッシュの料理の読み書き。登録簿の種類（`DishRecordKind`）が使う。保存は呼び出し側が行う
extension CachedDish {
    nonisolated static func find(id: UUID, in context: ModelContext) throws -> CachedDish? {
        var descriptor = FetchDescriptor<CachedDish>(predicate: #Predicate { $0.dishId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func upsert(_ dish: Dish, in context: ModelContext) throws {
        if let existing = try find(id: dish.id, in: context) {
            existing.apply(dish)
        } else {
            context.insert(CachedDish(dish))
        }
    }
}
