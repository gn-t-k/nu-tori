import Foundation
import NuToriCore
import SwiftData

/// キャッシュの食事の読み書き。登録簿の種類（`MealRecordKind`）が使う。保存は呼び出し側が行う
extension CachedMeal {
    nonisolated static func find(id: UUID, in context: ModelContext) throws -> CachedMeal? {
        var descriptor = FetchDescriptor<CachedMeal>(predicate: #Predicate { $0.mealId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func upsert(_ meal: Meal, in context: ModelContext) throws {
        if let existing = try find(id: meal.id, in: context) {
            existing.apply(meal)
        } else {
            context.insert(CachedMeal(meal))
        }
    }
}
