import { generateRecordId, type RecordId } from "../../domain/record-id";
import type { DishEstimationApplication, NewDish } from "../../dish/domain/dish";
import { computeUtcOffsetSeconds } from "../../domain/compute-utc-offset-seconds";
import { createRecordLedger } from "../../domain/create-record-ledger";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { RecordType } from "../../domain/record-type";
import type { LedgerStore } from "../../domain/sync-ledger/ledger-store";
import type { RecordChangeTarget } from "../../domain/sync-ledger/record-change-target";
import type { UsageEvent } from "../../domain/usage-event";
import type { NewIngredient } from "../../ingredient/domain/ingredient";
import type { Meal } from "../../meal/domain/meal";
import type { BegunEstimationAttempt } from "./begin-estimation-attempts";
import { abandonEstimation } from "./abandon-estimation";
import { applyDishEstimation } from "./apply-dish-estimation";
import { computeEstimationEndedEvent } from "./compute-estimation-ended-event";
import type { EstimatedDish } from "./estimated-dish";
import type { EstimatedWrittenMeals, EstimationAttemptOutcome } from "./estimation-attempt-outcome";
import type { EstimationWrites } from "./estimation-writes";
import { findEstimationOrigin } from "./find-estimation-origin";
import { maximumEstimationAttempts } from "./maximum-estimation-attempts";

// 呼び出しから戻ったときに、1つのトランザクションで試みの結果を書く。
// 食事・料理とのつなぎが無ければ（呼び出し中に食事・料理が消えた）結果だけで終え、二度と呼ばない（届いた推定は捨てる）。
// 食事が対象なら、通ったら料理・当てた推定と推定の量・材料・完了を書く。文章の食事なら、1つ目の食事の時刻と2つめ以降の食事も同じトランザクションで書く。料理が対象なら、完了か断念を書き、当てるなら料理に当てる。料理と材料の変更は run の中で足すので、推定の書き込みの口が足す推定の状態の変更より前に並ぶ。400 か、試みが上限に達したら諦める。
// 返すのは PostHog に送る出来事
export const recordEstimationAttemptOutcome = (
  ledgerStore: LedgerStore<RecordType>,
  stores: RecordKindStores,
  attempt: BegunEstimationAttempt,
  outcome: EstimationAttemptOutcome,
  endedAt: Date,
): UsageEvent[] =>
  createRecordLedger(ledgerStore, stores, endedAt).changeOutsideWrites((addChange) =>
    stores.writeEstimationEvents(addChange, endedAt, (writes) => {
      const { estimationId } = attempt;
      writes.recordAttemptResult({ attemptId: attempt.attemptId, endedAt, conclusion: outcome });
      const attemptEnded: UsageEvent = {
        name: "estimation_attempt_ended",
        result: outcome.result,
        identifyDishesUsage: outcome.usage.identifyDishes,
        matchIngredientsUsage: outcome.usage.matchIngredients,
      };
      const target = stores.estimation.findTargetOfEstimation(estimationId);
      if (target === undefined) {
        return [attemptEnded];
      }
      const attempts = stores.estimation.findAttempts(estimationId);
      const computeEnded = (
        finalStatus: "estimated" | "no_dishes" | "failed",
        dishCount: number,
        ingredients: readonly Pick<NewIngredient, "nutrientSource">[],
      ) =>
        computeEstimationEndedEvent({
          ...findEstimationOrigin(stores, target, estimationId),
          finalStatus,
          attempts,
          endedAt,
          dishCount,
          ingredients,
        });

      if (outcome.result === "succeeded") {
        if (target.type === "dish") {
          const [estimated] = outcome.dishes;
          const result = estimated === undefined ? "no_dishes" : "estimated";
          writes.complete({ estimationId, target, completedAt: endedAt, result });
          applyDishEstimation(stores, addChange, {
            dishId: target.dishId,
            estimationId,
            estimated,
          });
          return [
            attemptEnded,
            computeEnded(result, outcome.dishes.length, estimated?.ingredients ?? []),
          ];
        }
        const dishCount =
          outcome.dishes.length +
          (outcome.writtenMeals?.laterMeals.reduce((sum, meal) => sum + meal.dishes.length, 0) ??
            0);
        const result = dishCount === 0 ? "no_dishes" : "estimated";
        writes.complete({ estimationId, target, completedAt: endedAt, result });
        const ingredients = [
          ...insertEstimatedDishes(stores, addChange, target.mealId, estimationId, outcome.dishes),
          ...(outcome.writtenMeals === undefined
            ? []
            : recordWrittenMeals(stores, writes, addChange, {
                mealId: target.mealId,
                estimationId,
                writtenMeals: outcome.writtenMeals,
              })),
        ];
        return [attemptEnded, computeEnded(result, dishCount, ingredients)];
      }
      if (outcome.result === "bad_request" || attempts.length >= maximumEstimationAttempts) {
        abandonEstimation(stores, writes, addChange, {
          estimationId,
          target,
          abandonedAt: endedAt,
        });
        return [attemptEnded, computeEnded("failed", 0, [])];
      }
      return [attemptEnded];
    }),
  );

// 推定した料理・当てた推定・材料を食事に書き、料理と材料の変更を足す。書いた材料を返す
const insertEstimatedDishes = (
  stores: RecordKindStores,
  addChange: (change: RecordChangeTarget<RecordType>) => void,
  mealId: RecordId,
  estimationId: string,
  estimated: readonly EstimatedDish[],
): NewIngredient[] => {
  const { dishes, applications, ingredients } = toRecords(mealId, estimationId, estimated);
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
  return ingredients;
};

// 文章の食事の推定（#419 の「文章の食事」）。1つ目の食事（予定のつなぎの食事）に推定した時刻を書き、
// 時刻の違う食事を、同じ送った文章の文章の食事として作って料理と材料を書く。2つめ以降の食事の推定の状態は、この推定から出す。
// 1つ目の食事の今の時刻が変わったとき（使う人が直していないとき）だけ、食事の変更を足す。書いた材料を返す
const recordWrittenMeals = (
  stores: RecordKindStores,
  writes: EstimationWrites,
  addChange: (change: RecordChangeTarget<RecordType>) => void,
  {
    mealId,
    estimationId,
    writtenMeals,
  }: { mealId: RecordId; estimationId: string; writtenMeals: EstimatedWrittenMeals },
): NewIngredient[] => {
  const first = stores.meal.find(mealId);
  if (first === undefined) {
    throw new Error(`推定の予定につながっている食事が無い: ${mealId}`);
  }
  writes.estimateMealEatenAt({ estimationId, eatenAt: writtenMeals.eatenAt });
  if (stores.meal.find(mealId)?.eatenAt.getTime() !== first.eatenAt.getTime()) {
    addChange({ recordType: "meal", recordId: mealId });
  }
  return writtenMeals.laterMeals.flatMap(({ eatenAt, dishes }) => {
    const meal: Meal = {
      id: generateRecordId(),
      eatenAt,
      eatenAtUtcOffsetSeconds: computeUtcOffsetSeconds(eatenAt, first.sentTimeZone),
      sentAt: first.sentAt,
      sentTimeZone: first.sentTimeZone,
      entryMethod: "written",
      photoIds: [],
      sentTextId: first.sentTextId,
    };
    stores.meal.insert(meal);
    addChange({ recordType: "meal", recordId: meal.id });
    writes.recordCreatedMeal({ mealId: meal.id, estimationId });
    return insertEstimatedDishes(stores, addChange, meal.id, estimationId, dishes);
  });
};

const toRecords = (
  mealId: RecordId,
  estimationId: string,
  estimated: readonly EstimatedDish[],
): {
  dishes: NewDish[];
  applications: DishEstimationApplication[];
  ingredients: NewIngredient[];
} => {
  const withIds = estimated.map(({ ingredients, name, quantity, unit }, index) => {
    const dishId = generateRecordId();
    return {
      dish: { id: dishId, mealId, name, positionInMeal: index },
      application: { dishId, estimationId, estimatedQuantity: { quantity, unit } },
      ingredients: ingredients.map((ingredient, positionInDish) => ({
        ...ingredient,
        id: generateRecordId(),
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
