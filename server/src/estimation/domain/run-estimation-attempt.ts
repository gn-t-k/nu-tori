import { R } from "@praha/byethrow";
import { ErrorFactory } from "@praha/error-factory";
import { match } from "ts-pattern";
import type { RecordId } from "../../domain/record-id";
import { loadFoodComposition } from "../../domain/food-composition/food-composition";
import { isNutrientName } from "../../domain/food-composition/nutrient-name";
import type { IngredientNutrientSource } from "../../ingredient/domain/ingredient";
import type { MealPhotoArchive } from "../../meal/domain/meal-photo-archive";
import type { BegunEstimationAttempt, WrittenMealTarget } from "./begin-estimation-attempts";
import type { EstimatedDish } from "./estimated-dish";
import type { EstimationAttemptOutcome } from "./estimation-attempt-outcome";
import { estimationAttemptTimeLimitMs } from "./estimation-attempt-time-limit-ms";
import type { EstimationAttemptUsage } from "./estimation-attempt-usage";
import type {
  EstimationProvider,
  EstimationProviderReply,
  IdentifiedDishes,
  IdentifiedIngredient,
  IdentificationTarget,
  IngredientMatch,
  IngredientMatchRequest,
  MatchedIngredients,
  TokenUsage,
} from "./estimation-provider";
import { computeWrittenMealEatenAt, toWrittenMealsRequest } from "./written-meal-eaten-at";

// 試み1回分。写真を R2 から読み、①（写真から料理と材料。推定し直しでは写真と料理の今の値から、その料理1つ。
// 文章の食事では、写真の代わりに送った文章から、時刻の違う食事ごとの料理と材料）→ 成分表の候補 → ②（候補から選ぶか主な栄養を推定）と進め、応答を確かめる。
// 提供元の失敗と、確かめに通らない応答は、試みの結果として返す。
// R2 と成分表の読み込みの失敗は投げる（試みは結果の無いまま、途中で止まった試みとして数える）
export const runEstimationAttempt = async (
  deps: { archive: MealPhotoArchive; provider: EstimationProvider },
  request: Pick<BegunEstimationAttempt, "photoIds" | "target">,
): Promise<EstimationAttemptOutcome> => {
  const { target } = request;
  const photos =
    target.type === "written_meal" ? [] : await readPhotos(deps.archive, request.photoIds);
  const signal = AbortSignal.timeout(estimationAttemptTimeLimitMs);
  const attempted = await R.pipe(
    target.type === "written_meal"
      ? identifyWrittenMeals(deps.provider, target.sentText, signal)
      : identifyDishes(deps.provider, { photos, target }, signal),
    R.andThen(({ identified, dishEatenAts }) =>
      R.pipe(
        matchIngredients(deps.provider, identified, signal),
        R.map(({ dishes, usage }) => ({
          usage,
          ...(dishEatenAts === undefined
            ? { dishes, writtenMeals: undefined }
            : toWrittenMeals(dishes, dishEatenAts)),
        })),
      ),
    ),
  );
  // 通らなかった試みも結果として書くので、ここで提供元の Result を試みの結果に直す
  return R.isSuccess(attempted)
    ? { result: "succeeded", ...attempted.value }
    : attempted.error.outcome;
};

// ① の確かめに通った料理と、文章の食事なら料理ごとの食べた時刻（範囲に収めたもの。料理と同じ並び）
type Identified = {
  identified: EstimationProviderReply<IdentifiedDishes>;
  dishEatenAts: Date[] | undefined;
};

const identifyDishes = (
  provider: EstimationProvider,
  request: { photos: readonly ArrayBuffer[]; target: IdentificationTarget },
  signal: AbortSignal,
): R.ResultAsync<Identified, EstimationAttemptFailedError> =>
  R.pipe(
    provider.identifyDishes(request, signal),
    R.mapError((error) =>
      toAttemptFailed(error, "identify_dishes", {
        identifyDishes: usageOf(error),
        matchIngredients: undefined,
      }),
    ),
    R.andThen((identified) =>
      isValidIdentifiedDishes(identified.output, request.target)
        ? R.succeed({ identified, dishEatenAts: undefined })
        : R.fail(invalidIdentification(identified.usage)),
    ),
  );

// 文章の食事の ①。食事の並びを料理の並びに開き、料理ごとに食事の時刻を持たせる（② を1回で呼ぶため）
const identifyWrittenMeals = (
  provider: EstimationProvider,
  sentText: WrittenMealTarget["sentText"],
  signal: AbortSignal,
): R.ResultAsync<Identified, EstimationAttemptFailedError> =>
  R.pipe(
    provider.identifyWrittenMeals(toWrittenMealsRequest(sentText), signal),
    R.mapError((error) =>
      toAttemptFailed(error, "identify_dishes", {
        identifyDishes: usageOf(error),
        matchIngredients: undefined,
      }),
    ),
    R.andThen(({ output, usage }) => {
      const eatenAts = output.meals.map(({ eatenAt }) =>
        computeWrittenMealEatenAt(eatenAt, sentText),
      );
      const dishes = output.meals.flatMap(({ dishes: mealDishes }) => mealDishes);
      if (
        !eatenAts.every((eatenAt): eatenAt is Date => eatenAt !== undefined) ||
        !isValidIdentifiedDishes({ dishes }, { type: "meal" })
      ) {
        return R.fail(invalidIdentification(usage));
      }
      const dishEatenAts = output.meals.flatMap(({ dishes: mealDishes }, index) =>
        mealDishes.map(() => eatenAts[index] ?? sentText.sentAt),
      );
      return R.succeed({ identified: { output: { dishes }, usage }, dishEatenAts });
    }),
  );

const invalidIdentification = (usage: TokenUsage): EstimationAttemptFailedError =>
  new EstimationAttemptFailedError({
    outcome: {
      result: "invalid_response",
      failedStage: "identify_dishes",
      usage: { identifyDishes: usage, matchIngredients: undefined },
    },
  });

// 同じ時刻の料理を1つの食事にまとめる（範囲の外の日時は送った時刻にそろうので、そこで重なりうる）。
// 1つ目の食事は、① が最初に返した食事
const toWrittenMeals = (
  dishes: readonly EstimatedDish[],
  dishEatenAts: readonly Date[],
): Pick<Extract<EstimationAttemptOutcome, { result: "succeeded" }>, "dishes" | "writtenMeals"> => {
  const meals: { eatenAt: Date; dishes: EstimatedDish[] }[] = [];
  for (const [index, dish] of dishes.entries()) {
    const eatenAt = dishEatenAts[index];
    if (eatenAt === undefined) {
      throw new Error("料理ごとの食べた時刻が、料理より少ない");
    }
    const sameTime = meals.find((meal) => meal.eatenAt.getTime() === eatenAt.getTime());
    if (sameTime === undefined) {
      meals.push({ eatenAt, dishes: [dish] });
    } else {
      sameTime.dishes.push(dish);
    }
  }
  const [first, ...laterMeals] = meals;
  return first === undefined
    ? { dishes: [], writtenMeals: undefined }
    : { dishes: first.dishes, writtenMeals: { eatenAt: first.eatenAt, laterMeals } };
};

// R2 と成分表の段で止まった。stage は、アラームの呼び出しごとのログに出す失敗した段
export class EstimationAttemptStoppedError extends ErrorFactory({
  name: "EstimationAttemptStoppedError",
  message: "推定の試みが途中で止まった",
  fields: ErrorFactory.fields<{ stage: "read_photos" | "find_candidates" }>(),
}) {}

type FailedOutcome = Exclude<EstimationAttemptOutcome, { result: "succeeded" }>;

type ProviderFailure = R.InferFailure<EstimationProvider["identifyDishes"]>;

// 提供元の失敗と、確かめに通らない応答。試みの結果に直すまで、提供元の Result の失敗としてつなぐ
class EstimationAttemptFailedError extends ErrorFactory({
  name: "EstimationAttemptFailedError",
  message: "推定の試みが通らなかった",
  fields: ErrorFactory.fields<{ outcome: FailedOutcome }>(),
}) {}

const readPhotos = async (
  archive: MealPhotoArchive,
  photoIds: readonly RecordId[],
): Promise<ArrayBuffer[]> => {
  try {
    const photos = await Promise.all(photoIds.map((photoId) => archive.read(photoId)));
    return photos.map((photo) => {
      if (photo === undefined) {
        throw new Error("受け取った写真が R2 に無い");
      }
      return photo;
    });
  } catch (cause) {
    throw new EstimationAttemptStoppedError({ stage: "read_photos", cause });
  }
};

// 栄養成分表示の無い材料だけを ② に渡す。どの材料にも表示があれば ② を呼ばない
const matchIngredients = (
  provider: EstimationProvider,
  identified: EstimationProviderReply<IdentifiedDishes>,
  signal: AbortSignal,
): R.ResultAsync<
  { dishes: EstimatedDish[]; usage: EstimationAttemptUsage },
  EstimationAttemptFailedError
> => {
  const unlabeled = identified.output.dishes
    .flatMap(({ ingredients }) => ingredients)
    .filter(({ nutritionLabel }) => nutritionLabel === undefined);
  if (unlabeled.length === 0) {
    return Promise.resolve(
      R.succeed({
        dishes: composeDishes(identified.output, []),
        usage: { identifyDishes: identified.usage, matchIngredients: undefined },
      }),
    );
  }
  const request = { ingredients: unlabeled.map(findCandidates) };
  return R.pipe(
    provider.matchIngredients(request, signal),
    R.mapError((error) =>
      toAttemptFailed(error, "match_ingredients", {
        identifyDishes: identified.usage,
        matchIngredients: usageOf(error),
      }),
    ),
    R.andThen((matched) => {
      const usage = { identifyDishes: identified.usage, matchIngredients: matched.usage };
      return isValidMatchedIngredients(request, matched.output)
        ? R.succeed({ dishes: composeDishes(identified.output, matched.output.ingredients), usage })
        : R.fail(
            new EstimationAttemptFailedError({
              outcome: { result: "invalid_response", failedStage: "match_ingredients", usage },
            }),
          );
    }),
  );
};

const findCandidates = (
  ingredient: IdentifiedIngredient,
): IngredientMatchRequest["ingredients"][number] => {
  const candidatesPerIngredient = 8;
  try {
    return {
      name: ingredient.name,
      foodCompositionQuery: ingredient.foodCompositionQuery,
      candidates: loadFoodComposition()
        .findCandidates(ingredient.foodCompositionQuery, candidatesPerIngredient)
        .map(({ foodNumber, name }) => ({ foodNumber, name })),
    };
  } catch (cause) {
    throw new EstimationAttemptStoppedError({ stage: "find_candidates", cause });
  }
};

// 栄養の出どころは、栄養成分表示、成分表、AI の推定の順。matches は表示の無い材料の並びの答え
const composeDishes = (
  identified: IdentifiedDishes,
  matches: readonly IngredientMatch[],
): EstimatedDish[] => {
  const remainingMatches = [...matches];
  return identified.dishes.map(({ name, quantity, unit, ingredients }) => ({
    name,
    quantity,
    unit,
    ingredients: ingredients.map((ingredient) => {
      const { nutrientSource, nutrients } =
        ingredient.nutritionLabel === undefined
          ? toMatchedNutrients(remainingMatches.shift())
          : {
              nutrientSource: {
                type: "nutrition_label",
                labelBasisGrams: ingredient.nutritionLabel.basisGrams,
              } satisfies IngredientNutrientSource,
              nutrients: Object.fromEntries(
                Object.entries(ingredient.nutritionLabel.nutrients).filter(([nutrient]) =>
                  isNutrientName(nutrient),
                ),
              ),
            };
      return {
        name: ingredient.name,
        quantity: ingredient.quantity,
        unit: ingredient.unit,
        edibleGramsPerUnit: ingredient.edibleGramsPerUnit,
        nutrientSource,
        nutrients,
      };
    }),
  }));
};

const toMatchedNutrients = (
  matched: IngredientMatch | undefined,
): Pick<EstimatedDish["ingredients"][number], "nutrientSource" | "nutrients"> => {
  if (matched === undefined) {
    throw new Error("確かめに通った ② の答えが、表示の無い材料より少ない");
  }
  return match(matched)
    .with({ source: "food_composition" }, ({ foodNumber }) => {
      const entry = loadFoodComposition().findByFoodNumber(foodNumber);
      if (entry === undefined) {
        throw new Error(`候補にあった食品番号が成分表に無い: ${foodNumber}`);
      }
      return {
        nutrientSource: { type: "food_composition", foodNumber } as const,
        // 成分表の「-」は不明で、項目を持たない
        nutrients: entry.nutrients,
      };
    })
    .with({ source: "estimated" }, ({ nutrients }) => ({
      nutrientSource: { type: "estimated" } as const,
      nutrients,
    }))
    .exhaustive();
};

const toAttemptFailed = (
  error: ProviderFailure,
  failedStage: "identify_dishes" | "match_ingredients",
  usage: EstimationAttemptUsage,
): EstimationAttemptFailedError =>
  new EstimationAttemptFailedError({
    outcome: match(error)
      .with({ name: "EstimationProviderError" }, ({ errorType, cause }): FailedOutcome => ({
        result: "provider_error",
        failedStage,
        usage,
        errorType,
        providerError: cause,
      }))
      .with(
        { name: "EstimationProviderBadRequestError" },
        ({ errorType, cause }): FailedOutcome => ({
          result: "bad_request",
          failedStage,
          usage,
          errorType,
          providerError: cause,
        }),
      )
      .with({ name: "EstimationProviderTimedOutError" }, (): FailedOutcome => ({
        result: "timed_out",
        failedStage,
        usage,
      }))
      .with({ name: "EstimationProviderInvalidResponseError" }, (): FailedOutcome => ({
        result: "invalid_response",
        failedStage,
        usage,
      }))
      .exhaustive(),
  });

// 読めなかった応答でも、使ったトークンは分かる
const usageOf = (error: ProviderFailure) =>
  error.name === "EstimationProviderInvalidResponseError" ? error.usage : undefined;

// Claude の構造化出力は数値の範囲を使えないので、量が 0 より大きいことなどをここで確かめる。
// 推定し直しは、その料理1つか、材料を出せない（0 件）の答えだけを通す
const isValidIdentifiedDishes = (
  { dishes }: IdentifiedDishes,
  target: IdentificationTarget,
): boolean =>
  (target.type === "meal" || dishes.length <= 1) &&
  dishes.every(
    (dish) =>
      isPresentText(dish.name) &&
      isPositive(dish.quantity) &&
      isPresentText(dish.unit) &&
      dish.ingredients.length > 0 &&
      dish.ingredients.every(
        (ingredient) =>
          isPresentText(ingredient.name) &&
          isPositive(ingredient.quantity) &&
          isPresentText(ingredient.unit) &&
          isPositive(ingredient.edibleGramsPerUnit) &&
          (ingredient.nutritionLabel === undefined ||
            (isPositive(ingredient.nutritionLabel.basisGrams) &&
              Object.entries(ingredient.nutritionLabel.nutrients).every(
                ([nutrient, amount]) => isNutrientName(nutrient) && isNonNegative(amount),
              ))),
      ),
  );

// 答えは要求と同じ数で、食品番号は候補から選んでいること
const isValidMatchedIngredients = (
  request: IngredientMatchRequest,
  { ingredients }: MatchedIngredients,
): boolean =>
  ingredients.length === request.ingredients.length &&
  ingredients.every((matched, index) =>
    match(matched)
      .with({ source: "food_composition" }, ({ foodNumber }) =>
        (request.ingredients[index]?.candidates ?? []).some(
          (candidate) => candidate.foodNumber === foodNumber,
        ),
      )
      .with({ source: "estimated" }, ({ nutrients }) =>
        Object.values(nutrients).every(isNonNegative),
      )
      .exhaustive(),
  );

const isPresentText = (text: string): boolean => text.trim().length > 0;

const isPositive = (value: number): boolean => Number.isFinite(value) && value > 0;

const isNonNegative = (value: number): boolean => Number.isFinite(value) && value >= 0;
