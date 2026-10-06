import { match, P } from "ts-pattern";
import type { UsageEvent } from "../../domain/usage-event";
import type { Ingredient } from "../../ingredient/domain/ingredient";
import type { EstimationAttemptConclusion } from "./estimation-attempt-conclusion";
import type { EstimationAttempt } from "./estimation-store";

// 推定ごとの出来事。料理と材料は、推定できたときだけ数える（料理なし・諦めた・食事が消えたは 0）
export const computeEstimationEndedEvent = (ended: {
  trigger: Extract<UsageEvent, { name: "estimation_ended" }>["trigger"];
  finalStatus: Extract<UsageEvent, { name: "estimation_ended" }>["finalStatus"];
  attempts: readonly EstimationAttempt[];
  receivedAt: Date;
  endedAt: Date;
  dishCount: number;
  ingredients: readonly Pick<Ingredient, "nutrientSource">[];
}): UsageEvent => {
  const countIngredientsFrom = (type: Ingredient["nutrientSource"]["type"]) =>
    ended.ingredients.filter(({ nutrientSource }) => nutrientSource.type === type).length;
  return {
    name: "estimation_ended",
    trigger: ended.trigger,
    finalStatus: ended.finalStatus,
    retryCount: Math.max(ended.attempts.length - 1, 0),
    dishCount: ended.dishCount,
    ingredientCount: ended.ingredients.length,
    nutritionLabelIngredientCount: countIngredientsFrom("nutrition_label"),
    foodCompositionIngredientCount: countIngredientsFrom("food_composition"),
    estimatedIngredientCount: countIngredientsFrom("estimated"),
    secondsFromReceivedToEnded: Math.round(
      (ended.endedAt.getTime() - ended.receivedAt.getTime()) / 1000,
    ),
    providerErrorTypes: [
      ...new Set(
        ended.attempts.flatMap(({ ended: attemptEnded }) =>
          attemptEnded === undefined ? [] : toErrorTypes(attemptEnded.conclusion),
        ),
      ),
    ],
  };
};

const toErrorTypes = (conclusion: EstimationAttemptConclusion): string[] =>
  match(conclusion)
    .returnType<string[]>()
    .with({ result: P.union("succeeded", "timed_out", "invalid_response") }, () => [])
    .with({ result: P.union("provider_error", "bad_request") }, ({ errorType }) => [errorType])
    .exhaustive();
