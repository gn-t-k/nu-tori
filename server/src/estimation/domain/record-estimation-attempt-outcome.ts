import type { DishEstimationApplication, NewDish } from "../../dish/domain/dish";
import { createRecordLedger } from "../../domain/create-record-ledger";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { RecordType } from "../../domain/record-type";
import type { LedgerStore } from "../../domain/sync-ledger/ledger-store";
import type { UsageEvent } from "../../domain/usage-event";
import type { Ingredient } from "../../ingredient/domain/ingredient";
import type { BegunEstimationAttempt } from "./begin-estimation-attempts";
import { computeEstimationEndedEvent } from "./compute-estimation-ended-event";
import type { EstimatedDish } from "./estimated-dish";
import type { EstimationAttemptOutcome } from "./estimation-attempt-outcome";
import { findMealReceivedAt } from "./find-meal-received-at";
import { maximumEstimationAttempts } from "./maximum-estimation-attempts";

// 呼び出しから戻ったときに、1つのトランザクションで試みの結果を書く。
// 食事とのつなぎが無ければ（呼び出し中に食事が消えた）結果だけで終え、二度と呼ばない。
// 通ったら料理・当てた推定と推定の量・材料・完了を書く。料理と材料の変更は run の中で足すので、推定の書き込みの口が足す推定の状態の変更より前に並ぶ。400 か、試みが上限に達したら諦める。
// 返すのは PostHog に送る出来事
export const recordEstimationAttemptOutcome = (
  ledgerStore: LedgerStore<RecordType>,
  stores: RecordKindStores,
  attempt: BegunEstimationAttempt,
  outcome: EstimationAttemptOutcome,
  endedAt: Date,
): UsageEvent[] =>
  createRecordLedger(ledgerStore, stores, endedAt).changeOutsideWrites((addChange) =>
    stores.writeEstimationEvents(addChange, (writes) => {
      const { estimationId } = attempt;
      writes.recordAttemptResult({ attemptId: attempt.attemptId, endedAt, conclusion: outcome });
      const attemptEnded: UsageEvent = {
        name: "estimation_attempt_ended",
        result: outcome.result,
        identifyDishesUsage: outcome.usage.identifyDishes,
        matchIngredientsUsage: outcome.usage.matchIngredients,
      };
      const mealId = stores.estimation.findMealIdOfEstimation(estimationId);
      if (mealId === undefined) {
        return [attemptEnded];
      }
      const attempts = stores.estimation.findAttempts(estimationId);
      const computeEnded = (
        finalStatus: "estimated" | "no_dishes" | "failed",
        dishes: readonly NewDish[],
        ingredients: readonly Ingredient[],
      ) =>
        computeEstimationEndedEvent({
          finalStatus,
          attempts,
          receivedAt: findMealReceivedAt(stores.estimationSchedule, mealId),
          endedAt,
          dishCount: dishes.length,
          ingredients,
        });

      if (outcome.result === "succeeded") {
        const { dishes, applications, ingredients } = toRecords(
          mealId,
          estimationId,
          outcome.dishes,
        );
        const result = dishes.length === 0 ? "no_dishes" : "estimated";
        writes.complete({ estimationId, mealId, completedAt: endedAt, result });
        for (const dish of dishes) {
          stores.dish.insert(dish);
        }
        for (const application of applications) {
          stores.dish.insertEstimationApplication(application);
        }
        for (const ingredient of ingredients) {
          stores.ingredient.insert(ingredient);
        }
        for (const { id } of dishes) {
          addChange({ recordType: "dish", recordId: id });
        }
        for (const { id } of ingredients) {
          addChange({ recordType: "ingredient", recordId: id });
        }
        return [attemptEnded, computeEnded(result, dishes, ingredients)];
      }
      if (outcome.result === "bad_request" || attempts.length >= maximumEstimationAttempts) {
        writes.abandon({ estimationId, mealId, abandonedAt: endedAt });
        return [attemptEnded, computeEnded("failed", [], [])];
      }
      return [attemptEnded];
    }),
  );

const toRecords = (
  mealId: string,
  estimationId: string,
  estimated: readonly EstimatedDish[],
): { dishes: NewDish[]; applications: DishEstimationApplication[]; ingredients: Ingredient[] } => {
  const withIds = estimated.map(({ ingredients, name, quantity, unit }, positionInMeal) => {
    const dishId = crypto.randomUUID();
    return {
      dish: { id: dishId, mealId, name, positionInMeal },
      application: { dishId, estimationId, estimatedQuantity: { quantity, unit } },
      ingredients: ingredients.map((ingredient, positionInDish) => ({
        ...ingredient,
        id: crypto.randomUUID(),
        dishId,
        estimationId,
        positionInDish,
      })),
    };
  });
  return {
    dishes: withIds.map(({ dish }) => dish),
    applications: withIds.map(({ application }) => application),
    ingredients: withIds.flatMap(({ ingredients }) => ingredients),
  };
};
