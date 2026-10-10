import type { RecordId } from "../../domain/record-id";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { RecordChangeTarget } from "../../domain/sync-ledger/record-change-target";
import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { UsageEvent } from "../../domain/usage-event";
import { deleteDishes } from "../../dish/domain/delete-dishes";
import { computeDishDeletedEstimationEvents } from "../../estimation/domain/compute-dish-deleted-estimation-events";
import { computeEstimationEndedEvent } from "../../estimation/domain/compute-estimation-ended-event";
import { findMealEstimationTrigger } from "../../estimation/domain/find-meal-estimation-trigger";
import { findMealReceivedAt } from "../../estimation/domain/find-meal-received-at";

// 食事を消す口が読み書きする置き場
export type MealDeletionStores = Pick<
  RecordKindStores,
  "meal" | "dish" | "dishEstimationStatus" | "ingredient" | "estimation" | "estimationSchedule"
>;

// 食事が消えるときに一緒に変わる記録の種類
export type MealDeletionChangeType =
  | "meal_estimation_status"
  | "dish"
  | "ingredient"
  | "dish_estimation_status";

// 食事を消す計画。食事を消す書き込みと、会話として送り直す書き込み（#419）が使う。読むだけで、書くのは commit
export type MealDeletionPlan = {
  // 食事の変更のほかに、一緒に届ける変更（推定の状態・料理・材料・推定し直しの予定のある料理の推定の状態）
  addedChanges: RecordChangeTarget<MealDeletionChangeType>[];
  // 推定中の食事と、推定し直しの推定中の料理なら、推定ごとの出来事を「食事が消えた」で送る
  usageEvents: UsageEvent[];
  // 食事の削除の印は書き込みごとに置き場が違う（食事を消す書き込みは meal_deletions、会話として送り直すは
  // conversation_resend_meal_deletions）ので、呼び出し側が insertDeletion で書く
  commit: (receiptId: WriteReceiptId, insertDeletion: () => void) => void;
};

// 料理・材料・写真の宣言を消し、それぞれの削除の印を残す。推定中なら、つなぎが CASCADE で消える前に推定を読む
export const planMealDeletion = (
  stores: MealDeletionStores,
  mealId: RecordId,
  deletedAt: Date,
): MealDeletionPlan => {
  const meal = stores.meal.find(mealId);
  const dishIds = stores.dish.findIdsOfMeal(mealId);
  const ingredientIds = stores.ingredient.findIdsOfMeal(mealId);
  const scheduledDishIds = dishIds.filter(
    (dishId) => stores.dishEstimationStatus.findSchedulesOfDish(dishId).length > 0,
  );
  return {
    addedChanges: [
      { recordType: "meal_estimation_status", recordId: mealId },
      ...dishIds.map((recordId) => ({ recordType: "dish" as const, recordId })),
      ...ingredientIds.map((recordId) => ({ recordType: "ingredient" as const, recordId })),
      ...scheduledDishIds.map((recordId) => ({
        recordType: "dish_estimation_status" as const,
        recordId,
      })),
    ],
    usageEvents: [
      ...computeMealDeletedEstimationEvents(stores, mealId, deletedAt),
      ...scheduledDishIds.flatMap((dishId) =>
        computeDishDeletedEstimationEvents(
          stores,
          { id: dishId, mealId },
          "meal_deleted",
          deletedAt,
        ),
      ),
    ],
    // #332 の「消す順」: 料理ごとの中身を消してから、食事の時刻の修正を消し、食事の削除の印を書いて食事を消す
    commit: (receiptId, insertDeletion) => {
      deleteDishes(stores, { dishIds, ingredientIds }, receiptId);
      stores.meal.removeCorrections(mealId);
      insertDeletion();
      if (meal !== undefined) {
        stores.meal.insertPhotoDeletions(meal.photoIds, receiptId);
        stores.meal.remove(mealId);
      }
    },
  };
};

const computeMealDeletedEstimationEvents = (
  stores: MealDeletionStores,
  mealId: RecordId,
  deletedAt: Date,
): UsageEvent[] => {
  const estimationId = stores.estimation.findOngoingEstimationIdOfMeal(mealId);
  if (estimationId === undefined) {
    return [];
  }
  return [
    computeEstimationEndedEvent({
      trigger: findMealEstimationTrigger(stores.meal, mealId),
      finalStatus: "meal_deleted",
      attempts: stores.estimation.findAttempts(estimationId),
      receivedAt: findMealReceivedAt(stores.estimationSchedule, mealId),
      endedAt: deletedAt,
      dishCount: 0,
      ingredients: [],
    }),
  ];
};
