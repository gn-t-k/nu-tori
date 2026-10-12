import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId } from "../../../domain/record-id";
import type { MealPhotoArchive } from "../../../meal/domain/meal-photo-archive";
import type { BegunEstimationAttempt } from "../begin-estimation-attempts";
import { LlmCallError } from "../../../domain/llm-call-error";
import { LlmCallInvalidResponseError } from "../../../domain/llm-call-invalid-response-error";
import type { EstimationProvider, IdentifiedDishes } from "../estimation-provider";
import { mockEstimationProviderError, mockEstimationProviderOk } from "../estimation-provider.mock";
import { runEstimationAttempt } from "./index";

// 東京の 2026-10-10（土）08:30
const saturdayMorningInTokyo = Date.UTC(2026, 9, 9, 23, 30);

const udon: IdentifiedDishes["dishes"][number] = {
  name: "かけうどん",
  quantity: 1,
  unit: "杯",
  ingredients: [
    {
      name: "うどん",
      quantity: 200,
      unit: "g",
      edibleGramsPerUnit: 1,
      foodCompositionQuery: "うどん ゆで",
      nutritionLabel: undefined,
    },
  ],
};

const bread: IdentifiedDishes["dishes"][number] = {
  name: "トースト",
  quantity: 1,
  unit: "枚",
  ingredients: [
    {
      name: "食パン",
      quantity: 1,
      unit: "枚",
      edibleGramsPerUnit: 60,
      foodCompositionQuery: "こむぎ 食パン",
      nutritionLabel: undefined,
    },
  ],
};

// 栄養成分表示のある材料だけの料理
const greenTea: IdentifiedDishes["dishes"][number] = {
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
      nutritionLabel: { basisGrams: 100, nutrients: { energy_kcal: 0 } },
    },
  ],
};

describe("推定の試み", () => {
  let archive: MealPhotoArchive;
  let photographedMeal: Pick<BegunEstimationAttempt, "photoIds" | "target">;
  let writtenMeal: Pick<BegunEstimationAttempt, "photoIds" | "target">;
  beforeEach(() => {
    archive = {
      put: () => Promise.resolve(),
      read: () => Promise.resolve(new ArrayBuffer(8)),
      remove: () => Promise.resolve(),
    };
    photographedMeal = { photoIds: [generateRecordId()], target: { type: "meal" } };
    writtenMeal = {
      photoIds: [],
      target: {
        type: "written_meal",
        sentText: {
          body: "食べたもの",
          sentAt: new Date(saturdayMorningInTokyo),
          timeZone: "Asia/Tokyo",
        },
      },
    };
  });

  describe("写真の食事で、提供元が料理ありで答えたとき", () => {
    let provider: ReturnType<typeof mockEstimationProviderOk>;
    beforeEach(() => {
      provider = mockEstimationProviderOk();
    });

    test("料理ごとに、材料の栄養の出どころと基準あたりの栄養の値を、成分表・AI の推定・栄養成分表示から決めること", async () => {
      expect(await runEstimationAttempt({ archive, provider }, photographedMeal)).toMatchObject({
        result: "succeeded",
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
                nutrientSource: { type: "food_composition", foodNumber: "11225" },
                // 成分表の (0) は 0 の値にし、「-」（ヨウ素・セレン・クロム・モリブデン・ビオチン）は持たない
                nutrients: {
                  energy_kcal: 145,
                  protein_g: 21.5,
                  fat_g: 4.5,
                  carbohydrate_g: 0,
                  fiber_g: 0,
                  salt_equivalent_g: 0.2,
                  cholesterol_mg: 120,
                  potassium_mg: 380,
                  calcium_mg: 7,
                  magnesium_mg: 29,
                  phosphorus_mg: 220,
                  iron_mg: 0.9,
                  zinc_mg: 2.6,
                  copper_mg: 0.06,
                  manganese_mg: 0.01,
                  vitamin_a_ug: 13,
                  vitamin_d_ug: 0,
                  vitamin_e_mg: 0.3,
                  vitamin_k_ug: 29,
                  vitamin_b1_mg: 0.14,
                  vitamin_b2_mg: 0.23,
                  niacin_mg: 6.7,
                  vitamin_b6_mg: 0.37,
                  vitamin_b12_ug: 0.4,
                  folate_ug: 10,
                  pantothenic_acid_mg: 1.33,
                  vitamin_c_mg: 3,
                  water_g: 68.1,
                },
              },
              {
                name: "ご飯",
                quantity: 200,
                unit: "g",
                edibleGramsPerUnit: 1,
                nutrientSource: { type: "estimated" },
                nutrients: {
                  energy_kcal: 156,
                  protein_g: 2.5,
                  fat_g: 0.3,
                  carbohydrate_g: 37.1,
                  fiber_g: 1.5,
                  salt_equivalent_g: 0,
                },
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
                nutrientSource: { type: "nutrition_label", labelBasisGrams: 100 },
                nutrients: { energy_kcal: 0, protein_g: 0, salt_equivalent_g: 0.02 },
              },
            ],
          },
        ],
        writtenMeals: undefined,
      });
    });

    test("② に、栄養成分表示の無い材料だけを、① が返した順に渡すこと", async () => {
      await runEstimationAttempt({ archive, provider }, photographedMeal);
      expect(
        provider.matchIngredients.mock.calls.map(([{ ingredients }]) =>
          ingredients.map(({ name, foodCompositionQuery }) => ({ name, foodCompositionQuery })),
        ),
      ).toEqual([
        [
          { name: "鶏もも肉", foodCompositionQuery: "にわとり 若どり もも 皮なし 焼き" },
          { name: "ご飯", foodCompositionQuery: "ご飯" },
        ],
      ]);
    });
  });

  describe("返った中身の検証", () => {
    describe("① が、料理を 0 件で返したとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({ identifiedDishes: { dishes: [] } });
      });

      test("料理の無い、通った試みにすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, photographedMeal)).toMatchObject({
          result: "succeeded",
          dishes: [],
        });
      });
    });

    describe("① が返した料理の量が 0 のとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifiedDishes: { dishes: [{ ...udon, quantity: 0 }] },
        });
      });

      test("① で確かめに通らない試みにすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, photographedMeal)).toMatchObject({
          result: "invalid_response",
          failedStage: "identify_dishes",
        });
      });
    });

    describe("① が返した料理に材料が無いとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifiedDishes: { dishes: [{ ...udon, ingredients: [] }] },
        });
      });

      test("① で確かめに通らない試みにすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, photographedMeal)).toMatchObject({
          result: "invalid_response",
          failedStage: "identify_dishes",
        });
      });
    });

    describe("① が返した材料の名前が空白だけのとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifiedDishes: {
            dishes: [
              {
                ...udon,
                ingredients: udon.ingredients.map((ingredient) => ({ ...ingredient, name: " " })),
              },
            ],
          },
        });
      });

      test("① で確かめに通らない試みにすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, photographedMeal)).toMatchObject({
          result: "invalid_response",
          failedStage: "identify_dishes",
        });
      });
    });

    describe("① が返した栄養成分表示に、知らない栄養の項目があるとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifiedDishes: {
            dishes: [
              {
                ...greenTea,
                ingredients: greenTea.ingredients.map((ingredient) => ({
                  ...ingredient,
                  nutritionLabel: { basisGrams: 100, nutrients: { caffeine_mg: 20 } },
                })),
              },
            ],
          },
        });
      });

      test("① で確かめに通らない試みにすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, photographedMeal)).toMatchObject({
          result: "invalid_response",
          failedStage: "identify_dishes",
        });
      });
    });

    describe("推定し直しで、① が料理を2つ返したとき", () => {
      let provider: EstimationProvider;
      let renamedDish: Pick<BegunEstimationAttempt, "photoIds" | "target">;
      beforeEach(() => {
        provider = mockEstimationProviderOk({ identifiedDishes: { dishes: [udon, bread] } });
        renamedDish = {
          photoIds: photographedMeal.photoIds,
          target: {
            type: "dish",
            dish: { name: "かけうどん", correctedIngredients: [], correctedQuantity: undefined },
          },
        };
      });

      test("① で確かめに通らない試みにすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, renamedDish)).toMatchObject({
          result: "invalid_response",
          failedStage: "identify_dishes",
        });
      });
    });

    describe("② の答えの食品番号が、成分表の候補に無いとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          matchIngredients: ({ ingredients }) => ({
            ingredients: ingredients.map(() => ({
              source: "food_composition",
              foodNumber: "99999",
            })),
          }),
        });
      });

      test("② で確かめに通らない試みにすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, photographedMeal)).toMatchObject({
          result: "invalid_response",
          failedStage: "match_ingredients",
        });
      });
    });

    describe("② の答えの数が、渡した材料の数より少ないとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({ matchIngredients: () => ({ ingredients: [] }) });
      });

      test("② で確かめに通らない試みにすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, photographedMeal)).toMatchObject({
          result: "invalid_response",
          failedStage: "match_ingredients",
        });
      });
    });

    describe("② が推定した栄養の値が負のとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          matchIngredients: ({ ingredients }) => ({
            ingredients: ingredients.map(() => ({
              source: "estimated",
              nutrients: {
                energy_kcal: -1,
                protein_g: 0,
                fat_g: 0,
                carbohydrate_g: 0,
                fiber_g: 0,
                salt_equivalent_g: 0,
              },
            })),
          }),
        });
      });

      test("② で確かめに通らない試みにすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, photographedMeal)).toMatchObject({
          result: "invalid_response",
          failedStage: "match_ingredients",
        });
      });
    });
  });

  describe("文章の食事の時刻", () => {
    describe("① が、送った時刻より前で 7 日以内の日時を返したとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifiedWrittenMeals: { meals: [{ eatenAt: "2026-10-09T19:00", dishes: [bread] }] },
        });
      });

      test("送ったタイムゾーンでのその日時にすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, writtenMeal)).toMatchObject({
          result: "succeeded",
          // 東京の 2026-10-09 19:00
          writtenMeals: { eatenAt: new Date(Date.UTC(2026, 9, 9, 10, 0)) },
        });
      });
    });

    describe("① が、送った時刻のちょうど 7 日前の日時を返したとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifiedWrittenMeals: { meals: [{ eatenAt: "2026-10-03T08:30", dishes: [bread] }] },
        });
      });

      test("その日時にすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, writtenMeal)).toMatchObject({
          result: "succeeded",
          writtenMeals: { eatenAt: new Date(saturdayMorningInTokyo - 7 * 86_400_000) },
        });
      });
    });

    describe("① が、送った時刻の 7 日前より 1 分前の日時を返したとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifiedWrittenMeals: { meals: [{ eatenAt: "2026-10-03T08:29", dishes: [bread] }] },
        });
      });

      test("送った時刻にすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, writtenMeal)).toMatchObject({
          result: "succeeded",
          writtenMeals: { eatenAt: new Date(saturdayMorningInTokyo) },
        });
      });
    });

    describe("① が、送った時刻ちょうどの日時を返したとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifiedWrittenMeals: { meals: [{ eatenAt: "2026-10-10T08:30", dishes: [bread] }] },
        });
      });

      test("その日時にすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, writtenMeal)).toMatchObject({
          result: "succeeded",
          writtenMeals: { eatenAt: new Date(saturdayMorningInTokyo) },
        });
      });
    });

    describe("① が、送った時刻より 1 分後の日時を返したとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifiedWrittenMeals: { meals: [{ eatenAt: "2026-10-10T08:31", dishes: [bread] }] },
        });
      });

      test("送った時刻にすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, writtenMeal)).toMatchObject({
          result: "succeeded",
          writtenMeals: { eatenAt: new Date(saturdayMorningInTokyo) },
        });
      });
    });

    describe("① が返した食事の1つに、日付として無い日時があるとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifiedWrittenMeals: {
            meals: [
              { eatenAt: "2026-10-10T07:00", dishes: [bread] },
              { eatenAt: "2026-02-30T12:00", dishes: [udon] },
            ],
          },
        });
      });

      test("① で確かめに通らない試みにすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, writtenMeal)).toMatchObject({
          result: "invalid_response",
          failedStage: "identify_dishes",
        });
      });
    });
  });

  describe("文章の食事のまとめ方", () => {
    describe("① が、時刻の違う食事を2つ返したとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifiedWrittenMeals: {
            meals: [
              { eatenAt: "2026-10-09T19:00", dishes: [bread] },
              { eatenAt: "2026-10-10T07:00", dishes: [udon, greenTea] },
            ],
          },
        });
      });

      test("最初に返った食事を1つ目の食事にし、ほかを2つめ以降の食事にして、食事ごとに料理を分けること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, writtenMeal)).toMatchObject({
          result: "succeeded",
          dishes: [{ name: "トースト" }],
          writtenMeals: {
            eatenAt: new Date(Date.UTC(2026, 9, 9, 10, 0)),
            laterMeals: [
              {
                eatenAt: new Date(Date.UTC(2026, 9, 9, 22, 0)),
                dishes: [
                  { name: "かけうどん", ingredients: [{ name: "うどん" }] },
                  { name: "緑茶", ingredients: [{ name: "緑茶" }] },
                ],
              },
            ],
          },
        });
      });
    });

    describe("① が範囲の外の日時の食事を2つ返し、どちらも送った時刻になるとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifiedWrittenMeals: {
            meals: [
              { eatenAt: "2026-10-10T12:00", dishes: [bread] },
              { eatenAt: "2026-10-10T19:00", dishes: [udon] },
            ],
          },
        });
      });

      test("同じ時刻の料理を、返った順に1つの食事にまとめること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, writtenMeal)).toMatchObject({
          result: "succeeded",
          dishes: [{ name: "トースト" }, { name: "かけうどん" }],
          writtenMeals: { eatenAt: new Date(saturdayMorningInTokyo), laterMeals: [] },
        });
      });
    });

    describe("① が返した時刻の違う食事が 1 分だけ離れているとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifiedWrittenMeals: {
            meals: [
              { eatenAt: "2026-10-10T07:00", dishes: [bread] },
              { eatenAt: "2026-10-10T07:01", dishes: [udon] },
            ],
          },
        });
      });

      test("まとめずに、別の食事にすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, writtenMeal)).toMatchObject({
          result: "succeeded",
          dishes: [{ name: "トースト" }],
          writtenMeals: {
            eatenAt: new Date(Date.UTC(2026, 9, 9, 22, 0)),
            laterMeals: [
              { eatenAt: new Date(Date.UTC(2026, 9, 9, 22, 1)), dishes: [{ name: "かけうどん" }] },
            ],
          },
        });
      });
    });

    describe("① が最初に返した食事に料理が無いとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifiedWrittenMeals: {
            meals: [
              { eatenAt: "2026-10-09T19:00", dishes: [] },
              { eatenAt: "2026-10-10T07:00", dishes: [udon] },
            ],
          },
        });
      });

      test("料理の無い食事を作らず、料理のある最初の食事を1つ目の食事にすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, writtenMeal)).toMatchObject({
          result: "succeeded",
          dishes: [{ name: "かけうどん" }],
          writtenMeals: { eatenAt: new Date(Date.UTC(2026, 9, 9, 22, 0)), laterMeals: [] },
        });
      });
    });

    describe("① が食事を 0 件で返したとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({ identifiedWrittenMeals: { meals: [] } });
      });

      test("料理も文章の食事の時刻も無い、通った試みにすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, writtenMeal)).toMatchObject({
          result: "succeeded",
          dishes: [],
          writtenMeals: undefined,
        });
      });
    });
  });

  describe("① と ② の使用量の分け方", () => {
    describe("① も ② も通ったとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifyDishesUsage: { inputTokens: 1500, outputTokens: 400 },
          matchIngredientsUsage: { inputTokens: 800, outputTokens: 200 },
        });
      });

      test("① と ② の使用量を、呼び出しごとに分けて返すこと", async () => {
        expect(await runEstimationAttempt({ archive, provider }, photographedMeal)).toMatchObject({
          result: "succeeded",
          usage: {
            identifyDishes: { inputTokens: 1500, outputTokens: 400 },
            matchIngredients: { inputTokens: 800, outputTokens: 200 },
          },
        });
      });
    });

    describe("どの材料にも栄養成分表示があるとき", () => {
      let provider: ReturnType<typeof mockEstimationProviderOk>;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifiedDishes: { dishes: [greenTea] },
          identifyDishesUsage: { inputTokens: 1500, outputTokens: 400 },
        });
      });

      test("② を呼ばず、② の使用量を持たないこと", async () => {
        expect({
          outcome: await runEstimationAttempt({ archive, provider }, photographedMeal),
          matchIngredientsCalls: provider.matchIngredients.mock.calls.length,
        }).toMatchObject({
          outcome: {
            result: "succeeded",
            usage: {
              identifyDishes: { inputTokens: 1500, outputTokens: 400 },
              matchIngredients: undefined,
            },
          },
          matchIngredientsCalls: 0,
        });
      });
    });

    describe("① で提供元がエラーを返したとき", () => {
      let provider: EstimationProvider;
      let providerError: Error;
      beforeEach(() => {
        providerError = new Error("overloaded");
        provider = mockEstimationProviderError(
          new LlmCallError({ errorType: "overloaded_error", cause: providerError }),
        );
      });

      test("どちらの使用量も持たず、① で落ちた提供元のエラーの試みにすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, photographedMeal)).toEqual({
          result: "provider_error",
          failedStage: "identify_dishes",
          usage: { identifyDishes: undefined, matchIngredients: undefined },
          errorType: "overloaded_error",
          providerError,
        });
      });
    });

    describe("① の応答を提供元が読めなかったとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderError(
          new LlmCallInvalidResponseError({
            usage: { inputTokens: 1200, outputTokens: 4096 },
          }),
        );
      });

      test("読めなかった応答が使ったトークンを、① の使用量にすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, photographedMeal)).toEqual({
          result: "invalid_response",
          failedStage: "identify_dishes",
          usage: {
            identifyDishes: { inputTokens: 1200, outputTokens: 4096 },
            matchIngredients: undefined,
          },
        });
      });
    });

    describe("① の答えが確かめに通らないとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          identifiedDishes: { dishes: [{ ...udon, quantity: 0 }] },
          identifyDishesUsage: { inputTokens: 1500, outputTokens: 400 },
        });
      });

      test("① の使用量だけを持つこと", async () => {
        expect(await runEstimationAttempt({ archive, provider }, photographedMeal)).toEqual({
          result: "invalid_response",
          failedStage: "identify_dishes",
          usage: {
            identifyDishes: { inputTokens: 1500, outputTokens: 400 },
            matchIngredients: undefined,
          },
        });
      });
    });

    describe("① は通り、② で提供元がエラーを返したとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderError(new LlmCallError({ errorType: "api_error" }), {
          failingCall: "match_ingredients",
        });
      });

      test("① の使用量だけを持ち、② で落ちた試みにすること", async () => {
        expect(await runEstimationAttempt({ archive, provider }, photographedMeal)).toMatchObject({
          result: "provider_error",
          failedStage: "match_ingredients",
          usage: {
            identifyDishes: { inputTokens: 1500, outputTokens: 400 },
            matchIngredients: undefined,
          },
        });
      });
    });

    describe("① は通り、② の応答を提供元が読めなかったとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderError(
          new LlmCallInvalidResponseError({
            usage: { inputTokens: 900, outputTokens: 4096 },
          }),
          { failingCall: "match_ingredients" },
        );
      });

      test("① の使用量と、読めなかった応答が使ったトークンを ② の使用量にして持つこと", async () => {
        expect(await runEstimationAttempt({ archive, provider }, photographedMeal)).toEqual({
          result: "invalid_response",
          failedStage: "match_ingredients",
          usage: {
            identifyDishes: { inputTokens: 1500, outputTokens: 400 },
            matchIngredients: { inputTokens: 900, outputTokens: 4096 },
          },
        });
      });
    });

    describe("② の答えが確かめに通らないとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        provider = mockEstimationProviderOk({
          matchIngredients: () => ({ ingredients: [] }),
          identifyDishesUsage: { inputTokens: 1500, outputTokens: 400 },
          matchIngredientsUsage: { inputTokens: 800, outputTokens: 200 },
        });
      });

      test("① と ② の使用量を持つこと", async () => {
        expect(await runEstimationAttempt({ archive, provider }, photographedMeal)).toEqual({
          result: "invalid_response",
          failedStage: "match_ingredients",
          usage: {
            identifyDishes: { inputTokens: 1500, outputTokens: 400 },
            matchIngredients: { inputTokens: 800, outputTokens: 200 },
          },
        });
      });
    });
  });
});
