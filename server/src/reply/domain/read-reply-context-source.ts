import { match } from "ts-pattern";
import { dishAwaitsReestimation } from "../../dish-estimation-status/domain/dish-awaits-reestimation";
import type { RecordId } from "../../domain/record-id";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import { computeMealEstimationStatus } from "../../meal-estimation-status/domain/compute-meal-estimation-status";
import type { MealEstimationStatus } from "../../meal-estimation-status/domain/meal-estimation-status";
import type { SentText } from "../../sent-text/domain/sent-text";
import type { WeightRecord } from "../../weight-record/domain/weight-record";
import { createWeightTrendKind } from "../../weight-trend/domain/create-weight-trend-kind";
import { weightTrendRecordId } from "../../weight-trend/domain/weight-trend-record-id";
import type {
  MealEstimationProgress,
  ReplyContextSource,
  ReplyContextSourceMeal,
} from "./reply-context-source";

// 返事の文脈を組み立てる元の記録を、置き場から読む。組み立てる関数（assembleReplyContext）が範囲で絞るので、多めに読む。
// 範囲は、応える文章の 9 日前から（72 時間の窓と、今日の 7 日前の 0:00 を、タイムゾーンによらず含む）
export const readReplyContextSource = (
  stores: Pick<
    RecordKindStores,
    | "sentText"
    | "reply"
    | "aiUtterance"
    | "meal"
    | "mealEstimationStatus"
    | "dish"
    | "dishEstimationStatus"
    | "ingredient"
    | "weightRecord"
  >,
  sentText: SentText,
  now: Date,
): ReplyContextSource => {
  const from = new Date(sentText.sentAt.getTime() - sourceDays * 86_400_000);
  const weightTrend = createWeightTrendKind(stores.weightRecord).readCurrent(weightTrendRecordId);
  return {
    sentText,
    sentTexts: stores.sentText.findSentSince(from).map((other) => ({
      sentText: other,
      replyRequest: stores.reply.hasRequest(other.id)
        ? { aiUtterance: stores.aiUtterance.findOfSentText(other.id) }
        : undefined,
    })),
    meals: stores.meal
      .findIdsSentOrEatenSince(from)
      .flatMap((mealId) => readMeal(stores, mealId, now)),
    weightRecords: readWeightRecords(stores, from, now),
    weightTrend: weightTrend.status === "value" ? weightTrend.value : [],
  };
};

const sourceDays = 9;

const readMeal = (
  stores: Pick<
    RecordKindStores,
    "meal" | "mealEstimationStatus" | "dish" | "dishEstimationStatus" | "ingredient"
  >,
  mealId: RecordId,
  now: Date,
): ReplyContextSourceMeal[] => {
  const meal = stores.meal.find(mealId);
  if (meal === undefined) {
    return [];
  }
  const dishIds = stores.dish.findIdsOfMeal(mealId);
  const dishes = dishIds
    .flatMap((dishId) => {
      const dish = stores.dish.find(dishId);
      return dish === undefined ? [] : [dish];
    })
    .toSorted((a, b) => a.positionInMeal - b.positionInMeal || a.id.localeCompare(b.id))
    .map((dish) => ({
      dish,
      ingredients: stores.ingredient
        .findCurrentIdsOfDish(dish.id)
        .flatMap((ingredientId) => {
          const ingredient = stores.ingredient.find(ingredientId);
          return ingredient === undefined ? [] : [ingredient];
        })
        .toSorted((a, b) => a.positionInDish - b.positionInDish || a.id.localeCompare(b.id)),
    }));
  const awaitsDish = dishes.some(({ dish }) =>
    dishAwaitsReestimation(stores.dishEstimationStatus, dish.id, now),
  );
  return [
    {
      meal,
      estimation: awaitsDish
        ? "awaiting"
        : toProgress(
            computeMealEstimationStatus(stores.mealEstimationStatus.findSchedulesOfMeal(mealId)),
          ),
      dishes,
    },
  ];
};

const toProgress = (status: MealEstimationStatus): MealEstimationProgress =>
  match(status)
    .returnType<MealEstimationProgress>()
    .with("awaiting_photos", "estimating", "deferred_to_next_day", () => "awaiting")
    .with("failed", () => "failed")
    .with("estimated", "no_dishes", () => "settled")
    .exhaustive();

// 範囲の記録と、範囲より前でも最後の体重記録（取り込んだものを含む）
const readWeightRecords = (
  stores: Pick<RecordKindStores, "weightRecord">,
  from: Date,
  now: Date,
): WeightRecord[] => {
  const lastId = stores.weightRecord.findAllInMeasuredOrder().at(-1)?.id;
  const ids = new Set([
    ...stores.weightRecord
      .findMeasuredBetween(from, new Date(now.getTime() + 1))
      .map(({ id }) => id),
    ...(lastId === undefined ? [] : [lastId]),
  ]);
  return [...ids].flatMap((id) => {
    const record = stores.weightRecord.find(id);
    return record === undefined ? [] : [record];
  });
};
