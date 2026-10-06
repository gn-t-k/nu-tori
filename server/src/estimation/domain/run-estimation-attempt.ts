import { R } from "@praha/byethrow";
import { ErrorFactory } from "@praha/error-factory";
import { match } from "ts-pattern";
import { loadFoodComposition } from "../../domain/food-composition/food-composition";
import { isNutrientName } from "../../domain/food-composition/nutrient-name";
import type { IngredientNutrientSource } from "../../ingredient/domain/ingredient";
import type { MealPhotoArchive } from "../../meal/domain/meal-photo-archive";
import type { EstimatedDish } from "./estimated-dish";
import type { EstimationAttemptOutcome } from "./estimation-attempt-outcome";
import { estimationAttemptTimeLimitMs } from "./estimation-attempt-time-limit-ms";
import type { EstimationAttemptUsage } from "./estimation-attempt-usage";
import type {
  DishToReestimate,
  EstimationProvider,
  EstimationProviderReply,
  IdentifiedDishes,
  IdentifiedIngredient,
  IngredientMatch,
  IngredientMatchRequest,
  MatchedIngredients,
} from "./estimation-provider";

// 試み1回分。写真を R2 から読み、①（写真から料理と材料。推定し直しでは写真と料理の今の値から、その料理1つ）→ 成分表の候補 → ②（候補から選ぶか主な栄養を推定）と進め、応答を確かめる。
// 提供元の失敗と、確かめに通らない応答は、試みの結果として返す。
// R2 と成分表の読み込みの失敗は投げる（試みは結果の無いまま、途中で止まった試みとして数える）
export const runEstimationAttempt = async (
  deps: { archive: MealPhotoArchive; provider: EstimationProvider },
  request: {
    photoIds: readonly string[];
    dish: DishToReestimate | undefined;
    addedDishNames: readonly string[];
  },
): Promise<EstimationAttemptOutcome> => {
  const photos = await readPhotos(deps.archive, request.photoIds);
  const signal = AbortSignal.timeout(estimationAttemptTimeLimitMs);
  const attempted = await R.pipe(
    deps.provider.identifyDishes(
      { photos, dish: request.dish, addedDishNames: request.addedDishNames },
      signal,
    ),
    R.mapError((error) =>
      toAttemptFailed(error, "identify_dishes", {
        identifyDishes: usageOf(error),
        matchIngredients: undefined,
      }),
    ),
    R.andThen((identified) =>
      isValidIdentifiedDishes(identified.output, request.dish)
        ? R.succeed(identified)
        : R.fail(
            new EstimationAttemptFailedError({
              outcome: {
                result: "invalid_response",
                failedStage: "identify_dishes",
                usage: { identifyDishes: identified.usage, matchIngredients: undefined },
              },
            }),
          ),
    ),
    R.andThen((identified) => matchIngredients(deps.provider, identified, signal)),
  );
  // 通らなかった試みも結果として書くので、ここで提供元の Result を試みの結果に直す
  return R.isSuccess(attempted)
    ? { result: "succeeded", ...attempted.value }
    : attempted.error.outcome;
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
  photoIds: readonly string[],
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
  reestimating: DishToReestimate | undefined,
): boolean =>
  (reestimating === undefined || dishes.length <= 1) &&
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
