import { R } from "@praha/byethrow";
import { vi } from "vitest";
import type {
  EstimationProvider,
  IdentifiedDishes,
  IngredientMatchRequest,
  MatchedIngredients,
  TokenUsage,
} from "../../domain/estimation-provider";
import * as module from "./index";

type IdentifyDishesRequest = Parameters<EstimationProvider["identifyDishes"]>[0];

type FakeReplies = {
  // 要求から答えを作るときは関数で渡す（偽物が受け取った ① の入力を確かめるのにも使う）
  identifiedDishes: IdentifiedDishes | ((request: IdentifyDishesRequest) => IdentifiedDishes);
  identifyDishesUsage: TokenUsage;
  // ② の答えを要求から作る
  matchIngredients: (request: IngredientMatchRequest) => MatchedIngredients;
  matchIngredientsUsage: TokenUsage;
  // ① を答える前に待つ。呼び出し中に止まる（終わらない Promise）と、呼び出し中に食事を消す、を作る
  replyAfter: Promise<void>;
};

// 料理ありで答える偽の提供元。既定は、栄養成分表示の写った料理と、成分表を引く材料と、成分表に無い材料。
// 推定し直し（要求に料理がある）の既定は、1つ目の料理を、直した名前と直した量で返す。
// 偽物の identifyDishes も呼び出しを記録する（受け取った ① の入力は readIdentifyDishesRequests で読む）
export const mockCreateEstimationProviderOk = (overrides?: Partial<FakeReplies>) => {
  const replies: FakeReplies = { ...defaultReplies, ...overrides };
  const provider: EstimationProvider = {
    identifyDishes: vi.fn<EstimationProvider["identifyDishes"]>(async (request) => {
      await replies.replyAfter;
      return R.succeed({
        output:
          typeof replies.identifiedDishes === "function"
            ? replies.identifiedDishes(request)
            : replies.identifiedDishes,
        usage: replies.identifyDishesUsage,
      });
    }),
    matchIngredients: async (request) =>
      R.succeed({
        output: replies.matchIngredients(request),
        usage: replies.matchIngredientsUsage,
      }),
  };
  return vi.spyOn(module, "createEstimationProvider").mockReturnValue(provider);
};

// 失敗で答える偽の提供元。failingCall が match_ingredients なら、① は既定の料理で通り、② で落ちる
export const mockCreateEstimationProviderError = (
  error: R.InferFailure<EstimationProvider["identifyDishes"]>,
  options: { failingCall: "identify_dishes" | "match_ingredients" } = {
    failingCall: "identify_dishes",
  },
) => {
  const provider: EstimationProvider = {
    identifyDishes: async (request) =>
      options.failingCall === "identify_dishes"
        ? R.fail(error)
        : R.succeed({
            output: identifyDefaultDishes(request),
            usage: defaultReplies.identifyDishesUsage,
          }),
    matchIngredients: async () => R.fail(error),
  };
  return vi.spyOn(module, "createEstimationProvider").mockReturnValue(provider);
};

const photoDishes: IdentifiedDishes = {
  dishes: [
    {
      name: "親子丼",
      quantity: 1,
      unit: "杯",
      ingredients: [
        {
          name: "鶏もも肉",
          quantity: 80,
          unit: "g",
          edibleGramsPerUnit: 1,
          foodCompositionQuery: "にわとり 若どり もも 皮なし 焼き",
          nutritionLabel: undefined,
        },
        {
          name: "ご飯",
          quantity: 200,
          unit: "g",
          edibleGramsPerUnit: 1,
          // 成分表の名前と字を共有しないので、候補が無い
          foodCompositionQuery: "ご飯",
          nutritionLabel: undefined,
        },
      ],
    },
    {
      name: "緑茶",
      quantity: 1,
      unit: "本",
      ingredients: [
        {
          name: "緑茶",
          quantity: 1,
          unit: "本",
          edibleGramsPerUnit: 500,
          foodCompositionQuery: "せん茶 浸出液",
          nutritionLabel: {
            basisGrams: 100,
            nutrients: { energy_kcal: 0, protein_g: 0, salt_equivalent_g: 0.02 },
          },
        },
      ],
    },
  ],
};

const identifyDefaultDishes = (request: IdentifyDishesRequest): IdentifiedDishes => {
  const [first] = photoDishes.dishes;
  if (request.target.type === "meal" || first === undefined) {
    return photoDishes;
  }
  const { dish } = request.target;
  return {
    dishes: [
      {
        ...first,
        name: dish.name,
        quantity: dish.correctedQuantity?.value ?? first.quantity,
        unit: dish.correctedQuantity?.unit ?? first.unit,
      },
    ],
  };
};

const defaultReplies: FakeReplies = {
  identifiedDishes: identifyDefaultDishes,
  identifyDishesUsage: { inputTokens: 1500, outputTokens: 400 },
  // 候補があれば1つ目を選び、無ければ主な栄養を推定する
  matchIngredients: (request) => ({
    ingredients: request.ingredients.map(({ candidates }) => {
      const [first] = candidates;
      return first === undefined
        ? {
            source: "estimated",
            nutrients: {
              energy_kcal: 156,
              protein_g: 2.5,
              fat_g: 0.3,
              carbohydrate_g: 37.1,
              fiber_g: 1.5,
              salt_equivalent_g: 0,
            },
          }
        : { source: "food_composition", foodNumber: first.foodNumber };
    }),
  }),
  matchIngredientsUsage: { inputTokens: 800, outputTokens: 200 },
  replyAfter: Promise.resolve(),
};
