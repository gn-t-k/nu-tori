public import Foundation

/// タイムラインに並べる食事のカードと会話の元を、キャッシュの種類ごとの記録から組む。
/// 種類をまたぐ届く順は約束されない（`docs/agents/sync.md` の「種類をまたぐ届く順」）ので、親より先に届いた子と状態も受け取り、親が届くまで並べない
public struct TimelineRecords: Sendable {
    /// 状態は、同じ親のものが重なっていたら、あとのものを取る（`statusesByParentId()`）
    public init(
        meals: [Meal],
        mealEstimationStatuses: [MealEstimationStatusSyncing.Status],
        dishes: [Dish],
        dishEstimationStatuses: [DishEstimationStatusSyncing.Status],
        ingredients: [Ingredient],
        sentTexts: [SentText],
        sentTextStatuses: [SentTextStatusSyncing.Status],
        replies: [AiUtterance]
    ) {
        self.meals = meals
        self.mealEstimationStatuses = mealEstimationStatuses.statusesByParentId()
        self.dishes = dishes
        self.dishEstimationStatuses = dishEstimationStatuses.statusesByParentId()
        self.ingredients = ingredients
        self.sentTexts = sentTexts
        self.sentTextStatuses = sentTextStatuses.statusesByParentId()
        self.replies = replies
    }

    /// 食事ごとのカード。並びは `meals` の順。
    /// `recordedOnThisDevice` はこの端末で記録した（元の写真を持っている）食事、`unsentDishIds` はまだ送れていない料理
    public func mealCards(recordedOnThisDevice: Set<UUID>, unsentDishIds: Set<UUID>) -> [MealCard] {
        // 食事ごとに全部を舐めないよう、親ごとにまとめてから渡す
        let dishesByMeal = Dictionary(grouping: dishes, by: \.mealId)
        let ingredientsByDish = Dictionary(grouping: ingredients, by: \.dishId)
        return meals.map { meal in
            let dishes = dishesByMeal[meal.id] ?? []
            return MealCard(
                meal: meal,
                status: mealEstimationStatuses[meal.id],
                recordedOnThisDevice: recordedOnThisDevice.contains(meal.id),
                dishes: dishes,
                ingredients: dishes.flatMap { ingredientsByDish[$0.id] ?? [] },
                dishEstimationStatuses: dishEstimationStatuses,
                unsentDishIds: unsentDishIds
            )
        }
    }

    /// 送った文章が届くまで、状態と返事は並ばない（`Timeline.Conversation`）
    public func conversation(streams: [UUID: ReplyStream]) -> Timeline.Conversation {
        Timeline.Conversation(
            sentTexts: sentTexts, statuses: sentTextStatuses, replies: replies, streams: streams)
    }

    private let meals: [Meal]
    private let mealEstimationStatuses: [UUID: MealEstimationStatus]
    private let dishes: [Dish]
    private let dishEstimationStatuses: [UUID: DishEstimationStatus]
    private let ingredients: [Ingredient]
    private let sentTexts: [SentText]
    private let sentTextStatuses: [UUID: SentTextStatus]
    private let replies: [AiUtterance]
}
