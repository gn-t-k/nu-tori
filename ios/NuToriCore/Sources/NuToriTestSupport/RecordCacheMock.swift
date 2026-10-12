public import Foundation
public import NuToriCore
import Synchronization

/// メモリのキャッシュ。記録の種類ごとに、NuToriCore のメモリの adapter（`…Cache`）を1つずつ持ち、NuToriCore の当て方（`CacheApplying`）が当てる。
/// 同期の働きの単体テストで、アプリの SwiftData のキャッシュの代わりに使う。
/// テストは、ID ごとの辞書（`meals` など）で今の値を確かめ、準備は adapter にじかに置くか、下の短い書き方で置く
public final class RecordCacheMock: Sendable {
    public init() {}

    public let accountSettingsCache = MemorySingleRecordCache<AccountSettings>()
    public let aiUtteranceCache = MemoryKeyedRecordCache<AiUtterance, UUID>(id: \.id)
    public let dishCache = MemoryKeyedRecordCache<Dish, UUID>(id: \.id)
    /// 料理の ID で引く
    public let dishEstimationStatusCache = MemoryKeyedRecordCache<
        DishEstimationStatusSyncing.Status, UUID
    >(id: \.dishId)
    public let ingredientCache = MemoryKeyedRecordCache<Ingredient, UUID>(id: \.id)
    public let mealCache = MemoryKeyedRecordCache<Meal, UUID>(id: \.id)
    /// 食事の ID で引く
    public let mealEstimationStatusCache = MemoryKeyedRecordCache<
        MealEstimationStatusSyncing.Status, UUID
    >(id: \.mealId)
    public let noticeCache = MemoryKeyedRecordCache<Notice, UUID>(id: \.id)
    public let sentTextCache = MemoryKeyedRecordCache<SentText, UUID>(id: \.id)
    /// 送った文章の ID で引く
    public let sentTextStatusCache = MemoryKeyedRecordCache<SentTextStatusSyncing.Status, UUID>(
        id: \.sentTextId)
    public let usualWeighingTimeCache = MemorySingleRecordCache<UsualWeighingTime>()
    public let weightRecordCache = MemoryKeyedRecordCache<WeightRecord, UUID>(id: \.id)
    public let weightTrendCache = MemorySingleRecordCache<WeightTrend>()

    public var records: [UUID: WeightRecord] { Self.byId(weightRecordCache.all(), \.id) }

    public var settings: AccountSettings? { accountSettingsCache.read() }

    public var meals: [UUID: Meal] { Self.byId(mealCache.all(), \.id) }

    /// 食事の ID ごとの推定の状態
    public var estimationStatuses: [UUID: MealEstimationStatus] {
        Self.byId(mealEstimationStatusCache.all(), \.mealId).mapValues(\.status)
    }

    /// 料理の ID ごとの料理
    public var dishes: [UUID: Dish] { Self.byId(dishCache.all(), \.id) }

    /// 料理の ID ごとの推定の状態
    public var dishEstimationStatuses: [UUID: DishEstimationStatus] {
        Self.byId(dishEstimationStatusCache.all(), \.dishId).mapValues(\.status)
    }

    /// 材料の ID ごとの材料
    public var ingredients: [UUID: Ingredient] { Self.byId(ingredientCache.all(), \.id) }

    /// 知らせの ID ごとの知らせ
    public var notices: [UUID: Notice] { Self.byId(noticeCache.all(), \.id) }

    public var usualWeighingTime: UsualWeighingTime? { usualWeighingTimeCache.read() }

    public var weightTrend: WeightTrend? { weightTrendCache.read() }

    /// 送った文章の ID ごとの送った文章
    public var sentTexts: [UUID: SentText] { Self.byId(sentTextCache.all(), \.id) }

    /// 送った文章の ID ごとの状態
    public var sentTextStatuses: [UUID: SentTextStatus] {
        Self.byId(sentTextStatusCache.all(), \.sentTextId).mapValues(\.status)
    }

    /// 返事の ID ごとの返事
    public var aiUtterances: [UUID: AiUtterance] { Self.byId(aiUtteranceCache.all(), \.id) }

    public func upsert(_ meal: Meal) {
        mealCache.upsert(meal)
    }

    public func remove(mealId: UUID) {
        mealCache.remove(id: mealId)
    }

    public func write(_ status: MealEstimationStatus, forMealId mealId: UUID) {
        mealEstimationStatusCache.upsert(.init(mealId: mealId, status: status))
    }

    public func upsert(_ dish: Dish) {
        dishCache.upsert(dish)
    }

    public func remove(dishId: UUID) {
        dishCache.remove(id: dishId)
    }

    public func write(_ status: DishEstimationStatus, forDishId dishId: UUID) {
        dishEstimationStatusCache.upsert(.init(dishId: dishId, status: status))
    }

    public func upsert(_ ingredient: Ingredient) {
        ingredientCache.upsert(ingredient)
    }

    public func remove(ingredientId: UUID) {
        ingredientCache.remove(id: ingredientId)
    }

    /// 名前の種類が当てられた変更の数。テスト用の種類が数えるのに使う
    public func appliedCount(of kind: RecordKindName) -> Int {
        appliedCounts.withLock { $0[kind, default: 0] }
    }

    public func didApply(_ count: Int, forKind kind: RecordKindName) {
        appliedCounts.withLock { $0[kind, default: 0] += count }
    }

    public func clearApplied(forKind kind: RecordKindName) {
        appliedCounts.withLock { $0[kind] = nil }
    }

    private static func byId<Record>(_ records: [Record], _ id: (Record) -> UUID) -> [UUID: Record]
    {
        Dictionary(records.map { (id($0), $0) }, uniquingKeysWith: { _, last in last })
    }

    private let appliedCounts = Mutex<[RecordKindName: Int]>([:])
}
