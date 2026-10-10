import Foundation
import NuToriCore
import SwiftData
import SwiftUI

/// キャッシュの記録と同期の状態、今日の日付を読んで、タイムラインの画面に渡す
struct TimelineScreenContainer: View {
    let clock: DeviceClock
    let rejectedLines: [RejectedLine]
    /// 送り待ちに料理を足す・名前を直す書き込みがある料理（まだ送れていない料理として見せる）
    let unsentDishIds: Set<UUID>
    /// まだ届いていない記録（薄く描く）
    let undeliveredRecords: UndeliveredRecords
    let capture: (ClientUsageEvent) async -> Void
    let reminderLanding: ReminderLanding?
    let noteReminderLanded: () -> Void
    let requestNotificationPermission: () async -> Void
    let prepareWeightEntry: () async -> Void
    let saveWeight: (WeightEntry.Write) async -> Void
    /// 入力欄から文章を送る。送れるかは書く欄が決め、送れるときだけ呼ぶ
    let sendText: (TextDraft) async -> Void
    /// 送った文章の ID ごとの、見守る要求で受け取っている途中の返事
    let replyStreams: [UUID: ReplyStream]
    let conversationActions: ConversationActions
    let accountActions: AccountActions
    let mealActions: MealActions
    /// この端末で記録した（元の大きさの写真を持っている）食事か
    let holdsMealOriginals: (_ mealId: UUID) async -> Bool

    var body: some View {
        TimelineScreen(
            records: cachedRecords.compactMap { $0.weightRecord() },
            weightTrend: CachedWeightTrendDay.weightTrend(of: cachedWeightTrendDays),
            initialPull: initialPull,
            today: clock.today(),
            now: clock.now,
            timeZone: clock.timeZone,
            rejectedLines: rejectedLines,
            meals: mealCards,
            notices: cachedNotices.compactMap { $0.notice() },
            undeliveredRecords: undeliveredRecords,
            capture: capture,
            reminderLanding: reminderLanding,
            noteReminderLanded: noteReminderLanded,
            requestNotificationPermission: requestNotificationPermission,
            prepareWeightEntry: prepareWeightEntry,
            saveWeight: saveWeight,
            sendText: sendText,
            accountActions: accountActions,
            mealActions: mealActions,
            conversation: conversation,
            conversationActions: conversationActions
        )
        .task(id: cachedMeals.map(\.mealId)) {
            await readMealsRecordedHere()
        }
    }

    @Query private var cachedRecords: [CachedWeightRecord]
    @Query private var syncStates: [CachedSyncState]
    @Query private var cachedMeals: [CachedMeal]
    @Query private var cachedEstimationStatuses: [CachedMealEstimationStatus]
    @Query private var cachedDishes: [CachedDish]
    @Query private var cachedDishEstimationStatuses: [CachedDishEstimationStatus]
    @Query private var cachedIngredients: [CachedIngredient]
    @Query private var cachedNotices: [CachedNotice]
    @Query private var cachedWeightTrendDays: [CachedWeightTrendDay]
    @Query private var cachedSentTexts: [CachedSentText]
    @Query private var cachedSentTextStatuses: [CachedSentTextStatus]
    @Query private var cachedAiUtterances: [CachedAiUtterance]
    /// 写真の置き場を読み終えるまでは、ほかの端末の食事として見せる
    @State private var mealsRecordedHere: Set<UUID> = []

    private var initialPull: TimelineScreen.InitialPull {
        guard let state = syncStates.first, state.hasCompletedInitialPull else {
            return .inProgress
        }
        return .completed(startedDay: state.startedOn.flatMap(CalendarDay.init(yearMonthDay:)))
    }

    /// 推定の状態・料理・料理ごとの推定の状態・材料は食事と別の種類で、食事より先にも後にも届く
    private var mealCards: [MealCard] {
        var statuses: [UUID: MealEstimationStatus] = [:]
        for row in cachedEstimationStatuses {
            statuses[row.mealId] = row.estimationStatus()
        }
        // 食事ごとに全部を舐めないよう、親ごとにまとめてから渡す
        let dishesByMeal = Dictionary(grouping: cachedDishes.map { $0.dish() }, by: \.mealId)
        let ingredientsByDish = Dictionary(
            grouping: cachedIngredients.compactMap { $0.ingredient() }, by: \.dishId)
        var dishStatuses: [UUID: DishEstimationStatus] = [:]
        for row in cachedDishEstimationStatuses {
            dishStatuses[row.dishId] = row.estimationStatus()
        }
        return cachedMeals.compactMap { row in
            row.meal().map { meal in
                let dishes = dishesByMeal[meal.id] ?? []
                return MealCard(
                    meal: meal,
                    status: statuses[meal.id],
                    recordedOnThisDevice: mealsRecordedHere.contains(meal.id),
                    dishes: dishes,
                    ingredients: dishes.flatMap { ingredientsByDish[$0.id] ?? [] },
                    dishEstimationStatuses: dishStatuses,
                    unsentDishIds: unsentDishIds
                )
            }
        }
    }

    /// 送った文章・その状態・返事は別の種類で、どれが先にも届く。送った文章が届くまで、状態と返事は並ばない
    private var conversation: Timeline.Conversation {
        var statuses: [UUID: SentTextStatus] = [:]
        for row in cachedSentTextStatuses {
            statuses[row.sentTextId] = row.sentTextStatus()
        }
        return Timeline.Conversation(
            sentTexts: cachedSentTexts.compactMap { $0.sentText() },
            statuses: statuses,
            replies: cachedAiUtterances.map { $0.aiUtterance() },
            streams: replyStreams)
    }

    private func readMealsRecordedHere() async {
        var recordedHere: Set<UUID> = []
        for mealId in cachedMeals.map(\.mealId) {
            if await holdsMealOriginals(mealId) {
                recordedHere.insert(mealId)
            }
        }
        mealsRecordedHere = recordedHere
    }
}
