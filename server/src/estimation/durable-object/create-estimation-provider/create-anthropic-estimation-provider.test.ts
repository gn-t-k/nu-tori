import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import type { EstimationProvider, IngredientMatchRequest } from "../../domain/estimation-provider";
import { createAnthropicEstimationProvider } from "./create-anthropic-estimation-provider";
import { replyWithError } from "./testing/reply-with-error";
import { replyWithText } from "./testing/reply-with-text";
import { stubAnthropicApi } from "./testing/stub-anthropic-api";

// "account-1" の SHA-256（16 進）。ハッシュの正しさは、独立に計算した値で確かめる
const hashOfAccount1 = "07e998012c1137decdf3efbbb1c3ee6d79b015638cbc197bdbcce1875de4faad";

const chicken = {
  name: "鶏もも肉",
  quantity: 80,
  unit: "g",
  edibleGramsPerUnit: 1,
  foodCompositionQuery: "にわとり 若どり もも 皮なし 焼き",
  nutritionLabel: null,
};

const greenTea = {
  name: "緑茶",
  quantity: 1,
  unit: "本",
  edibleGramsPerUnit: 500,
  foodCompositionQuery: "せん茶 浸出液",
  nutritionLabel: {
    basisGrams: 100,
    nutrients: [
      { nutrient: "energy_kcal", amount: 0 },
      { nutrient: "salt_equivalent_g", amount: 0.02 },
    ],
  },
};

const oyakodonReply = {
  dishes: [{ name: "親子丼", quantity: 1, unit: "杯", ingredients: [chicken, greenTea] }],
};

const matchRequest: IngredientMatchRequest = {
  ingredients: [
    {
      name: "鶏もも肉",
      foodCompositionQuery: "にわとり 若どり もも 皮なし 焼き",
      candidates: [
        {
          foodNumber: "11225",
          name: "＜鳥肉類＞　にわとり　［若どり・主品目］　もも　皮なし　焼き",
        },
        { foodNumber: "11220", name: "＜鳥肉類＞　にわとり　［若どり・主品目］　もも　皮なし　生" },
      ],
    },
    { name: "ご飯", foodCompositionQuery: "ご飯", candidates: [] },
  ],
};

const estimatedNutrients = {
  energy_kcal: 156,
  protein_g: 2.5,
  fat_g: 0.3,
  carbohydrate_g: 37.1,
  fiber_g: 1.5,
  salt_equivalent_g: 0,
};

const photos = [new Uint8Array([1, 2, 3]).buffer, new Uint8Array([4, 5]).buffer];
const neverEnds = () => new AbortController().signal;

describe("createAnthropicEstimationProvider", () => {
  describe("① 写真から料理を読み取る", () => {
    describe("料理が写っているとき", () => {
      let provider: EstimationProvider;
      let requests: ReturnType<typeof stubAnthropicApi>["requests"];
      beforeEach(() => {
        const stub = stubAnthropicApi(async () =>
          replyWithText(JSON.stringify(oyakodonReply), {
            usage: { input_tokens: 1500, output_tokens: 400 },
          }),
        );
        requests = stub.requests;
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("料理・材料と使ったトークンを返すこと", async () => {
        const result = await provider.identifyDishes(
          { photos, target: { type: "meal" } },
          neverEnds(),
        );

        expect(result).toBeSuccess((reply) => {
          expect(reply.usage).toEqual({ inputTokens: 1500, outputTokens: 400 });
          expect(reply.output).toEqual({
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
                    name: "緑茶",
                    quantity: 1,
                    unit: "本",
                    edibleGramsPerUnit: 500,
                    foodCompositionQuery: "せん茶 浸出液",
                    nutritionLabel: {
                      basisGrams: 100,
                      nutrients: { energy_kcal: 0, salt_equivalent_g: 0.02 },
                    },
                  },
                ],
              },
            ],
          });
        });
      });

      test("Sonnet 5 に、思考を切り、アカウント ID のハッシュを添えて頼むこと", async () => {
        await provider.identifyDishes({ photos, target: { type: "meal" } }, neverEnds());

        expect(requests).toHaveLength(1);
        expect(requests[0]).toMatchObject({
          url: "https://api.anthropic.com/v1/messages",
          apiKey: "test-anthropic-api-key",
          body: {
            model: "claude-sonnet-5",
            thinking: { type: "disabled" },
            metadata: { user_id: hashOfAccount1 },
          },
        });
      });

      test("写真を JPEG の画像として、指示より前に渡すこと", async () => {
        await provider.identifyDishes({ photos, target: { type: "meal" } }, neverEnds());

        expect(requests[0]).toMatchObject({
          body: {
            messages: [
              {
                role: "user",
                content: [
                  {
                    type: "image",
                    source: { type: "base64", media_type: "image/jpeg", data: "AQID" },
                  },
                  {
                    type: "image",
                    source: { type: "base64", media_type: "image/jpeg", data: "BAU=" },
                  },
                  { type: "text" },
                ],
              },
            ],
          },
        });
      });

      test("構造化出力を求めること", async () => {
        await provider.identifyDishes({ photos, target: { type: "meal" } }, neverEnds());

        expect(requests[0]).toMatchObject({
          body: { output_config: { format: { type: "json_schema" } } },
        });
      });
    });

    describe("料理が写っていないとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () => replyWithText(JSON.stringify({ dishes: [] })));
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("料理 0 件で返すこと", async () => {
        const result = await provider.identifyDishes(
          { photos, target: { type: "meal" } },
          neverEnds(),
        );

        expect(result).toBeSuccess((reply) => {
          expect(reply.output).toEqual({ dishes: [] });
        });
      });
    });

    describe("応答が JSON でないとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () => replyWithText("すみません、読み取れません"));
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("使ったトークンを持つ、読めない応答の失敗で返すこと", async () => {
        const result = await provider.identifyDishes(
          { photos, target: { type: "meal" } },
          neverEnds(),
        );

        expect(result).toBeFailure((error) => {
          expect(error.name).toBe("EstimationProviderInvalidResponseError");
          expect(error).toMatchObject({ usage: { inputTokens: 1500, outputTokens: 400 } });
        });
      });
    });

    describe("応答の形が違うとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () =>
          replyWithText(JSON.stringify({ dishes: [{ name: "親子丼" }] })),
        );
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("使ったトークンを持つ、読めない応答の失敗で返すこと", async () => {
        const result = await provider.identifyDishes(
          { photos, target: { type: "meal" } },
          neverEnds(),
        );

        expect(result).toBeFailure((error) => {
          expect(error.name).toBe("EstimationProviderInvalidResponseError");
          expect(error).toMatchObject({ usage: { inputTokens: 1500, outputTokens: 400 } });
        });
      });
    });

    describe("知らない栄養の名前があるとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () =>
          replyWithText(
            JSON.stringify({
              dishes: [
                {
                  name: "緑茶",
                  quantity: 1,
                  unit: "本",
                  ingredients: [
                    {
                      ...greenTea,
                      nutritionLabel: {
                        basisGrams: 100,
                        nutrients: [{ nutrient: "vitamin_x", amount: 1 }],
                      },
                    },
                  ],
                },
              ],
            }),
          ),
        );
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("読めない応答の失敗で返すこと", async () => {
        const result = await provider.identifyDishes(
          { photos, target: { type: "meal" } },
          neverEnds(),
        );

        expect(result).toBeFailure((error) => {
          expect(error.name).toBe("EstimationProviderInvalidResponseError");
        });
      });
    });

    describe("出力の上限で途中で切れたとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () =>
          replyWithText('{"dishes":[{"name":"親子', { stopReason: "max_tokens" }),
        );
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("使ったトークンを持つ、読めない応答の失敗で返すこと", async () => {
        const result = await provider.identifyDishes(
          { photos, target: { type: "meal" } },
          neverEnds(),
        );

        expect(result).toBeFailure((error) => {
          expect(error.name).toBe("EstimationProviderInvalidResponseError");
          expect(error).toMatchObject({ usage: { inputTokens: 1500, outputTokens: 400 } });
        });
      });
    });

    describe("安全のために答えなかったとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () => replyWithText("", { stopReason: "refusal" }));
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("使ったトークンを持つ、読めない応答の失敗で返すこと", async () => {
        const result = await provider.identifyDishes(
          { photos, target: { type: "meal" } },
          neverEnds(),
        );

        expect(result).toBeFailure((error) => {
          expect(error.name).toBe("EstimationProviderInvalidResponseError");
          expect(error).toMatchObject({ usage: { inputTokens: 1500, outputTokens: 400 } });
        });
      });
    });
  });

  describe("① 名前を直した料理を推定し直す", () => {
    let provider: EstimationProvider;
    let requests: ReturnType<typeof stubAnthropicApi>["requests"];
    beforeEach(() => {
      const stub = stubAnthropicApi(async () => replyWithText(JSON.stringify(oyakodonReply)));
      requests = stub.requests;
      provider = createAnthropicEstimationProvider(stub.client, "account-1");
    });

    describe("直した材料と量があるとき", () => {
      let request: IdentifyDishesRequest;
      beforeEach(() => {
        request = {
          photos,
          target: {
            type: "dish",
            dish: {
              name: "カツ丼",
              correctedIngredients: [{ name: "ご飯", quantity: 150, unit: "g" }],
              correctedQuantity: { value: 1.5, unit: "杯" },
            },
          },
        };
      });

      test("写真のあとに、料理の今の名前と、直した材料の名前と量と、直した料理の量と単位を渡すこと", async () => {
        await provider.identifyDishes(request, neverEnds());

        expect(requests[0]).toMatchObject({
          body: {
            messages: [
              {
                content: [
                  { type: "image" },
                  { type: "image" },
                  {
                    type: "text",
                    text: expect.stringMatching(/「カツ丼」[\s\S]*ご飯 150 g[\s\S]*1\.5 杯/),
                  },
                ],
              },
            ],
          },
        });
      });
    });

    describe("直した材料も量も無いとき", () => {
      let request: IdentifyDishesRequest;
      beforeEach(() => {
        request = {
          photos,
          target: {
            type: "dish",
            dish: { name: "カツ丼", correctedIngredients: [], correctedQuantity: undefined },
          },
        };
      });

      test("それらを渡さないこと", async () => {
        await provider.identifyDishes(request, neverEnds());

        expect(requests[0]).toMatchObject({
          body: {
            messages: [
              {
                content: [
                  { type: "image" },
                  { type: "image" },
                  { type: "text", text: expect.not.stringMatching(/直した材料|料理の量は/) },
                ],
              },
            ],
          },
        });
      });
    });
  });

  describe("① 文章の食事の料理の名前を直して推定し直す（写真が無い）", () => {
    let requests: ReturnType<typeof stubAnthropicApi>["requests"];
    beforeEach(async () => {
      const stub = stubAnthropicApi(async () => replyWithText(JSON.stringify(oyakodonReply)));
      requests = stub.requests;
      await createAnthropicEstimationProvider(stub.client, "account-1").identifyDishes(
        {
          photos: [],
          target: {
            type: "dish",
            dish: { name: "きつねうどん", correctedIngredients: [], correctedQuantity: undefined },
          },
        },
        neverEnds(),
      );
    });

    test("画像を渡さず、写真が無いので名前から推定させる指示を渡すこと", () => {
      expect(requests[0]).toMatchObject({
        body: {
          messages: [
            {
              content: [
                {
                  type: "text",
                  text: expect.stringMatching(/「きつねうどん」[\s\S]*写真はありません/),
                },
              ],
            },
          ],
        },
      });
    });
  });

  describe("① 送った文章から食事を読み取る", () => {
    const request = {
      body: "昨日の夜はパン、今朝はうどん",
      sentAt: { localDateTime: "2026-10-10T08:30", dayOfWeek: "saturday" as const },
    };

    describe("時刻の違う食事を答えたとき", () => {
      let provider: EstimationProvider;
      let requests: ReturnType<typeof stubAnthropicApi>["requests"];
      beforeEach(() => {
        const stub = stubAnthropicApi(async () =>
          replyWithText(
            JSON.stringify({
              meals: [
                { eatenAt: "2026-10-09T19:00", dishes: oyakodonReply.dishes },
                { eatenAt: "2026-10-10T07:00", dishes: [] },
              ],
            }),
            { usage: { input_tokens: 900, output_tokens: 300 } },
          ),
        );
        requests = stub.requests;
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("食事ごとの日時と料理・材料と、使ったトークンを返すこと", async () => {
        const result = await provider.identifyWrittenMeals(request, neverEnds());

        expect(result).toBeSuccess((reply) => {
          expect(reply.usage).toEqual({ inputTokens: 900, outputTokens: 300 });
          expect(
            reply.output.meals.map(({ eatenAt, dishes }) => ({
              eatenAt,
              dishes: dishes.map(({ name, ingredients }) => ({
                name,
                ingredients: ingredients.map(({ name: ingredientName, nutritionLabel }) => ({
                  name: ingredientName,
                  nutritionLabel,
                })),
              })),
            })),
          ).toEqual([
            {
              eatenAt: "2026-10-09T19:00",
              dishes: [
                {
                  name: "親子丼",
                  ingredients: [
                    { name: "鶏もも肉", nutritionLabel: undefined },
                    {
                      name: "緑茶",
                      nutritionLabel: {
                        basisGrams: 100,
                        nutrients: { energy_kcal: 0, salt_equivalent_g: 0.02 },
                      },
                    },
                  ],
                },
              ],
            },
            { eatenAt: "2026-10-10T07:00", dishes: [] },
          ]);
        });
      });

      test("画像を渡さず、送った日時と曜日と文章を文字で渡し、思考を切ってハッシュを添えること", async () => {
        await provider.identifyWrittenMeals(request, neverEnds());

        expect(requests[0]).toMatchObject({
          body: {
            model: "claude-sonnet-5",
            thinking: { type: "disabled" },
            metadata: { user_id: hashOfAccount1 },
            output_config: { format: { type: "json_schema" } },
            messages: [
              {
                content: [
                  {
                    type: "text",
                    text: "送った日時: 2026-10-10 08:30（土曜日）\n送った文章:\n昨日の夜はパン、今朝はうどん",
                  },
                ],
              },
            ],
          },
        });
      });
    });

    describe("応答の形が違うとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () =>
          replyWithText(JSON.stringify({ dishes: oyakodonReply.dishes })),
        );
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("使ったトークンを持つ、読めない応答の失敗で返すこと", async () => {
        const result = await provider.identifyWrittenMeals(request, neverEnds());

        expect(result).toBeFailure((error) => {
          expect(error.name).toBe("EstimationProviderInvalidResponseError");
          expect(error).toMatchObject({ usage: { inputTokens: 1500, outputTokens: 400 } });
        });
      });
    });
  });

  describe("① 食事の写真を読み取る", () => {
    let provider: EstimationProvider;
    let requests: ReturnType<typeof stubAnthropicApi>["requests"];
    beforeEach(() => {
      const stub = stubAnthropicApi(async () => replyWithText(JSON.stringify(oyakodonReply)));
      requests = stub.requests;
      provider = createAnthropicEstimationProvider(stub.client, "account-1");
    });

    test("写真のあとに、食事の料理と材料を答える指示だけを渡すこと", async () => {
      await provider.identifyDishes({ photos, target: { type: "meal" } }, neverEnds());

      expect(requests[0]).toMatchObject({
        body: {
          messages: [
            {
              content: [
                { type: "image" },
                { type: "image" },
                { type: "text", text: "この食事の料理と材料を答えてください。" },
              ],
            },
          ],
        },
      });
    });
  });

  describe("② 候補から食品番号を選ぶ", () => {
    describe("選べた材料と、候補に無い材料があるとき", () => {
      let provider: EstimationProvider;
      let requests: ReturnType<typeof stubAnthropicApi>["requests"];
      beforeEach(() => {
        const stub = stubAnthropicApi(async () =>
          replyWithText(
            JSON.stringify({
              ingredients: [
                { foodNumber: "11225", estimatedNutrients: null },
                { foodNumber: null, estimatedNutrients },
              ],
            }),
            { usage: { input_tokens: 800, output_tokens: 200 } },
          ),
        );
        requests = stub.requests;
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("要求と同じ並びで、食品番号か推定した主な栄養を返すこと", async () => {
        const result = await provider.matchIngredients(matchRequest, neverEnds());

        expect(result).toBeSuccess((reply) => {
          expect(reply.usage).toEqual({ inputTokens: 800, outputTokens: 200 });
          expect(reply.output).toEqual({
            ingredients: [
              { source: "food_composition", foodNumber: "11225" },
              { source: "estimated", nutrients: estimatedNutrients },
            ],
          });
        });
      });

      test("写真は送らず、材料と候補を文字で渡し、思考を切ってハッシュを添えること", async () => {
        await provider.matchIngredients(matchRequest, neverEnds());

        expect(requests).toHaveLength(1);
        expect(requests[0]).toMatchObject({
          body: {
            model: "claude-sonnet-5",
            thinking: { type: "disabled" },
            metadata: { user_id: hashOfAccount1 },
            output_config: { format: { type: "json_schema" } },
            messages: [{ role: "user", content: [{ type: "text" }] }],
          },
        });
        const sentBody = JSON.stringify(requests[0]);
        expect(sentBody).toContain("11225");
        expect(sentBody).toContain("鶏もも肉");
        expect(sentBody).toContain("ご飯");
      });
    });

    describe("食品番号も推定した栄養も無い答えのとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () =>
          replyWithText(
            JSON.stringify({
              ingredients: [
                { foodNumber: null, estimatedNutrients: null },
                { foodNumber: null, estimatedNutrients },
              ],
            }),
          ),
        );
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("読めない応答の失敗で返すこと", async () => {
        const result = await provider.matchIngredients(matchRequest, neverEnds());

        expect(result).toBeFailure((error) => {
          expect(error.name).toBe("EstimationProviderInvalidResponseError");
        });
      });
    });
  });

  describe("提供元の呼び出しが失敗したとき", () => {
    describe("HTTP 400 のとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () =>
          replyWithError(400, "invalid_request_error", "Workspace spend limit reached"),
        );
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("提供元のエラーの種類を持つ 400 の失敗で返すこと", async () => {
        const result = await provider.identifyDishes(
          { photos, target: { type: "meal" } },
          neverEnds(),
        );

        expect(result).toBeFailure((error) => {
          expect(error.name).toBe("EstimationProviderBadRequestError");
          expect(error).toMatchObject({ errorType: "invalid_request_error" });
        });
      });
    });

    describe("HTTP 529（過負荷）のとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () => replyWithError(529, "overloaded_error", "busy"));
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("提供元のエラーの種類を持つ失敗で返すこと", async () => {
        const result = await provider.matchIngredients(matchRequest, neverEnds());

        expect(result).toBeFailure((error) => {
          expect(error.name).toBe("EstimationProviderError");
          expect(error).toMatchObject({ errorType: "overloaded_error" });
        });
      });
    });

    describe("HTTP 401（API キーが違う）のとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () =>
          replyWithError(401, "authentication_error", "invalid x-api-key"),
        );
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("400 とは分けて、提供元のエラーの失敗で返すこと", async () => {
        const result = await provider.identifyDishes(
          { photos, target: { type: "meal" } },
          neverEnds(),
        );

        expect(result).toBeFailure((error) => {
          expect(error.name).toBe("EstimationProviderError");
          expect(error).toMatchObject({ errorType: "authentication_error" });
        });
      });
    });

    describe("エラーの種類が応答に無いとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () => new Response("bad gateway", { status: 502 }));
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("HTTP の状態コードを種類にした失敗で返すこと", async () => {
        const result = await provider.identifyDishes(
          { photos, target: { type: "meal" } },
          neverEnds(),
        );

        expect(result).toBeFailure((error) => {
          expect(error.name).toBe("EstimationProviderError");
          expect(error).toMatchObject({ errorType: "http_502" });
        });
      });
    });

    describe("つなげなかったとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () => {
          throw new TypeError("fetch failed");
        });
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("connection_error の失敗で返すこと", async () => {
        const result = await provider.identifyDishes(
          { photos, target: { type: "meal" } },
          neverEnds(),
        );

        expect(result).toBeFailure((error) => {
          expect(error.name).toBe("EstimationProviderError");
          expect(error).toMatchObject({ errorType: "connection_error" });
        });
      });
    });

    describe("試み全体の時間の上限（signal）が切れたとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(() => new Promise(() => {}));
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      test("時間切れの失敗で返すこと", async () => {
        const result = await provider.identifyDishes(
          { photos, target: { type: "meal" } },
          AbortSignal.abort(),
        );

        expect(result).toBeFailure((error) => {
          expect(error.name).toBe("EstimationProviderTimedOutError");
        });
      });
    });

    describe("呼び出しごとの時間の上限を超えたとき", () => {
      let provider: EstimationProvider;
      beforeEach(() => {
        vi.useFakeTimers();
        const stub = stubAnthropicApi(() => new Promise(() => {}));
        provider = createAnthropicEstimationProvider(stub.client, "account-1");
      });

      afterEach(() => {
        vi.useRealTimers();
      });

      test("① は 90 秒で、時間切れの失敗で返すこと", async () => {
        const pending = provider.identifyDishes({ photos, target: { type: "meal" } }, neverEnds());

        await vi.advanceTimersByTimeAsync(90_000);

        expect(await pending).toBeFailure((error) => {
          expect(error.name).toBe("EstimationProviderTimedOutError");
        });
      });

      test("② は 60 秒で、時間切れの失敗で返すこと", async () => {
        const pending = provider.matchIngredients(matchRequest, neverEnds());

        await vi.advanceTimersByTimeAsync(60_000);

        expect(await pending).toBeFailure((error) => {
          expect(error.name).toBe("EstimationProviderTimedOutError");
        });
      });
    });
  });
});

// 推定の提供元の ① に渡す要求
type IdentifyDishesRequest = Parameters<EstimationProvider["identifyDishes"]>[0];
