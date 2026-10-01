import type { R } from "@praha/byethrow";
import type { NutrientName } from "../../domain/food-composition/nutrient-name";
import type { EstimationProviderBadRequestError } from "./estimation-provider-bad-request-error";
import type { EstimationProviderError } from "./estimation-provider-error";
import type { EstimationProviderInvalidResponseError } from "./estimation-provider-invalid-response-error";
import type { EstimationProviderTimedOutError } from "./estimation-provider-timed-out-error";

// 推定を頼む提供元（LLM）。① で写真から料理と材料を読み取り、② で材料ごとに成分表の候補から選ぶか主な栄養を推定する。
// 本物は Anthropic の API を呼ぶ（基盤に固有の層が実装する）。応答は残さず、推定の結果だけをドメイン層が書く。
// signal は試み（①②）の時間の上限で切れる。提供元は切れたら EstimationProviderTimedOutError で返す
export type EstimationProvider = {
  identifyDishes(
    request: { photos: readonly ArrayBuffer[] },
    signal: AbortSignal,
  ): R.ResultAsync<
    EstimationProviderReply<IdentifiedDishes>,
    | EstimationProviderError
    | EstimationProviderBadRequestError
    | EstimationProviderTimedOutError
    | EstimationProviderInvalidResponseError
  >;
  matchIngredients(
    request: IngredientMatchRequest,
    signal: AbortSignal,
  ): R.ResultAsync<
    EstimationProviderReply<MatchedIngredients>,
    | EstimationProviderError
    | EstimationProviderBadRequestError
    | EstimationProviderTimedOutError
    | EstimationProviderInvalidResponseError
  >;
};

export type EstimationProviderReply<TOutput> = {
  output: TOutput;
  // 呼び出しで実際に使ったトークン
  usage: TokenUsage;
};

export type TokenUsage = { inputTokens: number; outputTokens: number };

// ① の応答。料理が写っていない・見分けられないときは料理が 0 件
export type IdentifiedDishes = {
  dishes: readonly {
    name: string;
    quantity: number;
    unit: string;
    ingredients: readonly IdentifiedIngredient[];
  }[];
};

export type IdentifiedIngredient = {
  name: string;
  quantity: number;
  unit: string;
  edibleGramsPerUnit: number;
  // 成分表を引く語（調理の状態を含む）
  foodCompositionQuery: string;
  // 写真に栄養成分表示が写っていたときの値。nutrients は表示の単位（basisGrams g）あたりで、書かれていない栄養は持たない
  nutritionLabel: { basisGrams: number; nutrients: Readonly<Record<string, number>> } | undefined;
};

// ② に渡す、栄養成分表示の無い材料。並びの順に答えを返させる
export type IngredientMatchRequest = {
  ingredients: readonly {
    name: string;
    foodCompositionQuery: string;
    candidates: readonly { foodNumber: string; name: string }[];
  }[];
};

// ② の応答。要求の材料と同じ並び
export type MatchedIngredients = {
  ingredients: readonly IngredientMatch[];
};

export type IngredientMatch =
  | { source: "food_composition"; foodNumber: string }
  // 候補に無かった材料。主な栄養を可食部 100 g あたりで推定させる
  | { source: "estimated"; nutrients: Readonly<Record<MainNutrientName, number>> };

// AI の推定で出す主な栄養。ほかの項目は不明のまま
export type MainNutrientName = Extract<
  NutrientName,
  "energy_kcal" | "protein_g" | "fat_g" | "carbohydrate_g" | "fiber_g" | "salt_equivalent_g"
>;
