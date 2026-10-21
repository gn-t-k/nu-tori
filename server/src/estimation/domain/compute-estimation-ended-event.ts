import { match, P } from "ts-pattern";
import type { DishStore } from "../../dish/domain/dish-store";
import type { DishEstimationStatusStore } from "../../dish-estimation-status/domain/dish-estimation-status-store";
import type { UsageEvent } from "../../domain/usage-event";
import type { Ingredient } from "../../ingredient/domain/ingredient";
import type { MealStore } from "../../meal/domain/meal-store";
import type { EstimationEvents } from "./estimation-events";
import type { EstimationScheduleStore } from "./estimation-schedule-store";
import type { EstimationStore } from "./estimation-store";
import type { EstimationTarget } from "./estimation-target";
import { findEstimationOrigin } from "./find-estimation-origin";

// 推定ごとの出来事。推定を終える口（推定の書き込みの complete・abandon と、computeTargetDeletedEstimationEvents）だけが呼ぶ。
// 料理と材料は、推定できたときだけ数える（料理なし・諦めた・食事が消えたは 0）
export const computeEstimationEndedEvent = (
  stores: EstimationEndedEventStores,
  ended: {
    estimationId: string;
    target: EstimationTarget;
    finalStatus: Extract<UsageEvent, { name: "estimation_ended" }>["finalStatus"];
    endedAt: Date;
    dishCount: number;
    ingredients: readonly Pick<Ingredient, "nutrientSource">[];
  },
): UsageEvent => {
  const { trigger, receivedAt } = findEstimationOrigin(stores, ended.target, ended.estimationId);
  const attempts = stores.estimation.findAttempts(ended.estimationId);
  const countIngredientsFrom = (type: Ingredient["nutrientSource"]["type"]) =>
    ended.ingredients.filter(({ nutrientSource }) => nutrientSource.type === type).length;
  return {
    name: "estimation_ended",
    trigger,
    finalStatus: ended.finalStatus,
    retryCount: Math.max(attempts.length - 1, 0),
    dishCount: ended.dishCount,
    ingredientCount: ended.ingredients.length,
    nutritionLabelIngredientCount: countIngredientsFrom("nutrition_label"),
    foodCompositionIngredientCount: countIngredientsFrom("food_composition"),
    estimatedIngredientCount: countIngredientsFrom("estimated"),
    secondsFromReceivedToEnded: Math.round((ended.endedAt.getTime() - receivedAt.getTime()) / 1000),
    providerErrorTypes: [
      ...new Set(
        attempts.flatMap(({ ended: attemptEnded }) =>
          attemptEnded === undefined ? [] : toErrorTypes(attemptEnded.conclusion),
        ),
      ),
    ],
  };
};

// 推定を終えるときに読む置き場。きっかけと受け取った時刻、試みを読む
type EstimationEndedEventStores = {
  estimation: EstimationStore;
  estimationSchedule: EstimationScheduleStore;
  dishEstimationStatus: DishEstimationStatusStore;
  dish: DishStore;
  meal: MealStore;
};

const toErrorTypes = (conclusion: EstimationEvents["attemptResult"]["conclusion"]): string[] =>
  match(conclusion)
    .returnType<string[]>()
    .with({ result: P.union("succeeded", "timed_out", "invalid_response") }, () => [])
    .with({ result: P.union("provider_error", "bad_request") }, ({ errorType }) => [errorType])
    .exhaustive();
