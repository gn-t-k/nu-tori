import Foundation
import NuToriCore
import SwiftData
import SwiftUI

/// キャッシュの記録と同期の状態、今日の日付を読んで、タイムラインの画面に渡す
struct TimelineScreenContainer: View {
    let clock: DeviceClock
    let rejectedLines: [RejectedLine]
    /// 送り待ちから作る見え方（まだ届いていない記録は薄く描き、まだ送れていない料理はそう見せる）
    let pendingAppearance: PendingAppearance
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
    let goalSetup: GoalSetupSession
    let conversationActions: ConversationActions
    let accountActions: AccountActions
    let mealActions: MealActions
    /// この端末で記録した（元の大きさの写真を持っている）食事か
    let holdsMealOriginals: (_ mealId: UUID) async -> Bool

    var body: some View {
        let joined = timelineRecords
        TimelineScreen(
            records: cachedRecords.compactMap { $0.weightRecord() },
            weightTrend: CachedWeightTrendDay.weightTrend(of: cachedWeightTrendDays),
            initialPull: initialPull,
            today: clock.today(),
            now: clock.now,
            timeZone: clock.timeZone,
            rejectedLines: rejectedLines,
            meals: joined.mealCards(
                recordedOnThisDevice: mealsRecordedHere,
                unsentDishIds: pendingAppearance.unsentDishIds),
            notices: cachedNotices.compactMap { $0.notice() },
            goals: cachedGoals.compactMap { $0.goal() },
            dailyGuides: cachedDailyGuides.compactMap { $0.dailyGuide() },
            weeklyReviews: cachedWeeklyReviews.compactMap { $0.record() },
            expenditureEstimates: cachedExpenditureEstimates.compactMap {
                $0.expenditureEstimate()
            },
            undeliveredRecords: pendingAppearance.undelivered,
            capture: capture,
            reminderLanding: reminderLanding,
            noteReminderLanded: noteReminderLanded,
            requestNotificationPermission: requestNotificationPermission,
            prepareWeightEntry: prepareWeightEntry,
            saveWeight: saveWeight,
            sendText: sendText,
            accountActions: accountActions,
            mealActions: mealActions,
            conversation: joined.conversation(streams: replyStreams),
            conversationActions: conversationActions,
            goalSetupFlow: GoalSetupNoticeCard.Flow(
                goalSetup.flow, on: .timeline, openedOn: goalSetup.place),
            goalScreenGoalSetupFlow: GoalSetupNoticeCard.Flow(
                goalSetup.flow, on: .goalScreen, openedOn: goalSetup.place),
            openGoalSetupFlow: goalSetup.open(from:on:)
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
    @Query private var cachedGoals: [CachedGoal]
    @Query private var cachedDailyGuides: [CachedDailyGuide]
    @Query private var cachedWeeklyReviews: [CachedWeeklyReview]
    @Query private var cachedExpenditureEstimates: [CachedExpenditureEstimate]
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

    /// 行を記録にするだけにし、種類をまたいで組むのは `TimelineRecords` が行う。読めない行は飛ばす
    private var timelineRecords: TimelineRecords {
        TimelineRecords(
            meals: cachedMeals.compactMap { $0.meal() },
            mealEstimationStatuses: cachedEstimationStatuses.compactMap { $0.record() },
            dishes: cachedDishes.map { $0.dish() },
            dishEstimationStatuses: cachedDishEstimationStatuses.compactMap { $0.record() },
            ingredients: cachedIngredients.compactMap { $0.ingredient() },
            sentTexts: cachedSentTexts.compactMap { $0.sentText() },
            sentTextStatuses: cachedSentTextStatuses.compactMap { $0.record() },
            replies: cachedAiUtterances.map { $0.aiUtterance() })
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
