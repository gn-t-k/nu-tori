import Foundation
import NuToriCore
import SwiftData
import SwiftUI

/// キャッシュの記録と同期の状態、今日の日付を読んで、タイムラインの画面に渡す
struct TimelineScreenContainer: View {
    let rejectedLines: [RejectedLine]
    let capture: (ClientUsageEvent) async -> Void
    let prepareWeightEntry: () async -> Void
    let saveWeight: (WeightEntry.Write) async -> Void
    let accountActions: AccountActions
    let mealActions: MealActions
    /// この端末で記録した（元の大きさの写真を持っている）食事か
    let holdsMealOriginals: (_ mealId: UUID) async -> Bool

    var body: some View {
        TimelineScreen(
            records: cachedRecords.compactMap { $0.weightRecord() },
            weightTrend: weightTrend,
            initialPull: initialPull,
            today: CalendarDay(containing: .now, in: .current),
            now: { .now },
            rejectedLines: rejectedLines,
            meals: mealCards,
            capture: capture,
            prepareWeightEntry: prepareWeightEntry,
            saveWeight: saveWeight,
            accountActions: accountActions,
            mealActions: mealActions
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
    @Query private var cachedIngredients: [CachedIngredient]
    @Query private var cachedWeightTrendDays: [CachedWeightTrendDay]
    /// 写真の置き場を読み終えるまでは、ほかの端末の食事として見せる
    @State private var mealsRecordedHere: Set<UUID> = []

    private var initialPull: TimelineScreen.InitialPull {
        guard let state = syncStates.first, state.hasCompletedInitialPull else {
            return .inProgress
        }
        return .completed(startedDay: state.startedOn.flatMap(TimelineDayText.day(from:)))
    }

    /// 並び全体が届くたびに置き換わる。行が無ければ傾向は無い
    private var weightTrend: WeightTrend? {
        let days = cachedWeightTrendDays.compactMap { $0.trendDay() }.sorted { $0.day < $1.day }
        return days.isEmpty ? nil : WeightTrend(days: days)
    }

    /// 推定の状態・料理・材料は食事と別の種類で、食事より先にも後にも届く
    private var mealCards: [MealCard] {
        var statuses: [UUID: MealEstimationStatus] = [:]
        for row in cachedEstimationStatuses {
            statuses[row.mealId] = row.estimationStatus()
        }
        // 食事ごとに全部を舐めないよう、親ごとにまとめてから渡す
        let dishesByMeal = Dictionary(grouping: cachedDishes.map { $0.dish() }, by: \.mealId)
        let ingredientsByDish = Dictionary(
            grouping: cachedIngredients.compactMap { $0.ingredient() }, by: \.dishId)
        return cachedMeals.compactMap { row in
            row.meal().map { meal in
                let dishes = dishesByMeal[meal.id] ?? []
                return MealCard(
                    meal: meal,
                    status: statuses[meal.id],
                    recordedOnThisDevice: mealsRecordedHere.contains(meal.id),
                    dishes: dishes,
                    ingredients: dishes.flatMap { ingredientsByDish[$0.id] ?? [] }
                )
            }
        }
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
