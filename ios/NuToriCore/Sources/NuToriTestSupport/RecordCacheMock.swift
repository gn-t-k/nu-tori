public import Foundation
public import NuToriCore
import Synchronization

/// メモリのキャッシュ。体重記録、アカウントの設定、食事、推定の状態、料理、材料を持つ。登録簿の種類（`WeightRecordKindMock` など）が当てる。
/// 同期の働きの単体テストで、アプリの SwiftData のキャッシュの代わりに使う
public final class RecordCacheMock: Sendable {
    public init() {}

    public var records: [UUID: WeightRecord] {
        storage.withLock { $0.records }
    }

    public var settings: AccountSettings? {
        storage.withLock { $0.settings }
    }

    public var meals: [UUID: Meal] {
        storage.withLock { $0.meals }
    }

    /// 食事の ID ごとの推定の状態
    public var estimationStatuses: [UUID: MealEstimationStatus] {
        storage.withLock { $0.estimationStatuses }
    }

    /// 料理の ID ごとの料理。親の食事がまだ無くても置く
    public var dishes: [UUID: Dish] {
        storage.withLock { $0.dishes }
    }

    /// 材料の ID ごとの材料。親の料理がまだ無くても置く
    public var ingredients: [UUID: Ingredient] {
        storage.withLock { $0.ingredients }
    }

    /// 名前の種類が当てられた変更の数。テスト用の種類が数えるのに使う
    public func appliedCount(of kind: RecordKindName) -> Int {
        storage.withLock { $0.appliedCounts[kind, default: 0] }
    }

    public func upsert(_ record: WeightRecord) {
        storage.withLock { $0.records[record.id] = record }
    }

    public func remove(recordId: UUID) {
        storage.withLock { $0.records[recordId] = nil }
    }

    public func write(_ settings: AccountSettings) {
        storage.withLock { $0.settings = settings }
    }

    public func upsert(_ meal: Meal) {
        storage.withLock { $0.meals[meal.id] = meal }
    }

    public func remove(mealId: UUID) {
        storage.withLock { $0.meals[mealId] = nil }
    }

    public func write(_ status: MealEstimationStatus, forMealId mealId: UUID) {
        storage.withLock { $0.estimationStatuses[mealId] = status }
    }

    public func removeEstimationStatus(forMealId mealId: UUID) {
        storage.withLock { $0.estimationStatuses[mealId] = nil }
    }

    public func upsert(_ dish: Dish) {
        storage.withLock { $0.dishes[dish.id] = dish }
    }

    public func remove(dishId: UUID) {
        storage.withLock { $0.dishes[dishId] = nil }
    }

    public func upsert(_ ingredient: Ingredient) {
        storage.withLock { $0.ingredients[ingredient.id] = ingredient }
    }

    public func remove(ingredientId: UUID) {
        storage.withLock { $0.ingredients[ingredientId] = nil }
    }

    public func clearDishes() {
        storage.withLock { $0.dishes = [:] }
    }

    public func clearIngredients() {
        storage.withLock { $0.ingredients = [:] }
    }

    public func clearMeals() {
        storage.withLock { $0.meals = [:] }
    }

    public func clearEstimationStatuses() {
        storage.withLock { $0.estimationStatuses = [:] }
    }

    public func didApply(_ count: Int, forKind kind: RecordKindName) {
        storage.withLock { $0.appliedCounts[kind, default: 0] += count }
    }

    public func clearRecords() {
        storage.withLock { $0.records = [:] }
    }

    public func clearSettings() {
        storage.withLock { $0.settings = nil }
    }

    public func clearApplied(forKind kind: RecordKindName) {
        storage.withLock { $0.appliedCounts[kind] = nil }
    }

    private struct Storage {
        var records: [UUID: WeightRecord] = [:]
        var settings: AccountSettings?
        var meals: [UUID: Meal] = [:]
        var estimationStatuses: [UUID: MealEstimationStatus] = [:]
        var dishes: [UUID: Dish] = [:]
        var ingredients: [UUID: Ingredient] = [:]
        var appliedCounts: [RecordKindName: Int] = [:]
    }

    private let storage = Mutex(Storage())
}
