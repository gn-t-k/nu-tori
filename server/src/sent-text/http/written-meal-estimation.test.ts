import { runDurableObjectAlarm } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { generateRecordId } from "../../domain/record-id";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { mockCreateEstimationProviderOk } from "../../estimation/durable-object/create-estimation-provider/create-estimation-provider.mock";
import { insertCountedEstimations } from "../../estimation/http/testing/insert-counted-estimations";
import {
  readIdentifyDishesRequests,
  readIdentifyWrittenMealsRequests,
} from "../../estimation/http/testing/read-identify-dishes-requests";
import { runEstimationAlarm } from "../../estimation/http/testing/run-estimation-alarm";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { waitForEstimationAttempts } from "../../estimation/http/testing/wait-for-estimation-attempts";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import { updateDishWrite } from "../../dish/http/testing/update-dish-write";
import { deleteMealWrite } from "../../meal/http/testing/delete-meal-write";
import { enableUsageEventSending } from "../../http/sync-routes/testing/enable-usage-event-sending";
import { signInTestAccount } from "../../http/testing";
import { createMealWrite } from "../../meal/http/testing/create-meal-write";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { updateMealWrite } from "../../meal/http/testing/update-meal-write";
import type { IdentifiedDishes } from "../../estimation/domain/estimation-provider";
import { mockCreateConversationProviderOk } from "../../reply/durable-object/create-conversation-provider/create-conversation-provider.mock";
import { createSentTextWrite } from "./testing/create-sent-text-write";

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

describe("文章の食事の推定", () => {
  let accountId: string;
  let sessionToken: string;
  let clock: ReturnType<typeof useFakeClock>;
  let pullRecordsOf: (kind: string) => Promise<Record<string, unknown>[]>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
    clock = useFakeClock(Date.now() + 86_400_000);
    mockCreateConversationProviderOk({ classification: "meal" });
    pullRecordsOf = async (kind) =>
      (await (await pullSyncChanges(sessionToken)).json<PullResult>()).changes
        .filter((change) => change.kind === kind)
        .map(({ record }) => record);
  });

  const sendText = async (sentText: Record<string, unknown>) => {
    const write = createSentTextWrite({ sentText });
    await pushSyncWrites(sessionToken, { writes: [write] });
    return String(write.sentText["id"]);
  };

  // 推定が1つの食事を日時 eatenAt で返したときの、食事の今の時刻
  const estimateWith = async (eatenAt: string) => {
    mockCreateEstimationProviderOk({
      identifiedWrittenMeals: { meals: [{ eatenAt, dishes: [bread] }] },
    });
    await sendText({ body: "朝はパン", sentAt: saturdayMorningInTokyo, timeZone: "Asia/Tokyo" });
    await runEstimationAlarm(accountId);
    return (await pullRecordsOf("meal")).map(({ eatenAt: mealEatenAt }) => mealEatenAt);
  };

  describe("食事と読み分けた文章を推定するとき", () => {
    let provider: ReturnType<typeof mockCreateEstimationProviderOk>;
    beforeEach(async () => {
      provider = mockCreateEstimationProviderOk();
      await sendText({
        body: "朝はパン、昼はうどん",
        sentAt: saturdayMorningInTokyo,
        timeZone: "Asia/Tokyo",
      });
      await runEstimationAlarm(accountId);
    });

    test("① に、写真の代わりに文章と、送ったタイムゾーンでの送った日時と曜日を渡すこと", () => {
      expect(readIdentifyWrittenMealsRequests(provider)).toEqual([
        {
          body: "朝はパン、昼はうどん",
          sentAt: { localDateTime: "2026-10-10T08:30", dayOfWeek: "saturday" },
        },
      ]);
    });
  });

  describe("その日の推定が 30 回に達していて、翌日に推定するとき", () => {
    let provider: ReturnType<typeof mockCreateEstimationProviderOk>;
    beforeEach(async () => {
      provider = mockCreateEstimationProviderOk();
      const today = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Tokyo" }).format(Date.now());
      await insertCountedEstimations(accountId, today, 30);
      await sendText({
        body: "朝はパン",
        sentAt: saturdayMorningInTokyo,
        timeZone: "Asia/Tokyo",
      });
      await runEstimationAlarm(accountId);
      clock.advance(86_400_000);
      await runEstimationAlarm(accountId);
    });

    test("① に、推定する日でなく送った日時と曜日を渡すこと", async () => {
      expect({
        requests: readIdentifyWrittenMealsRequests(provider).map(({ sentAt }) => sentAt),
        statuses: (await pullRecordsOf("meal_estimation_status")).map(({ status }) => status),
      }).toEqual({
        requests: [{ localDateTime: "2026-10-10T08:30", dayOfWeek: "saturday" }],
        statuses: ["estimated"],
      });
    });
  });

  describe("推定が返した日時で、1つ目の食事の時刻を決めるとき", () => {
    test("送った時刻より前で 7 日以内なら、送ったタイムゾーンでのその日時にすること", async () => {
      // 東京の 2026-10-09 19:00
      expect(await estimateWith("2026-10-09T19:00")).toEqual([Date.UTC(2026, 9, 9, 10, 0)]);
    });

    test("ちょうど 7 日前なら、その日時にすること", async () => {
      expect(await estimateWith("2026-10-03T08:30")).toEqual([
        saturdayMorningInTokyo - 7 * 86_400_000,
      ]);
    });

    test("7 日より前なら、送った時刻にすること", async () => {
      expect(await estimateWith("2026-10-03T08:29")).toEqual([saturdayMorningInTokyo]);
    });

    test("送った時刻より後なら、送った時刻にすること", async () => {
      expect(await estimateWith("2026-10-10T08:31")).toEqual([saturdayMorningInTokyo]);
    });
  });

  describe("推定が終わる前に、使う人が時刻を直したとき", () => {
    let correctedAt: number;
    beforeEach(async () => {
      const { promise: replyAfter, resolve: reply } = Promise.withResolvers<void>();
      mockCreateEstimationProviderOk({
        replyAfter,
        identifiedWrittenMeals: { meals: [{ eatenAt: "2026-10-10T07:00", dishes: [bread] }] },
      });
      await sendText({ body: "朝はパン", sentAt: saturdayMorningInTokyo, timeZone: "Asia/Tokyo" });
      const alarm = runDurableObjectAlarm(getAccountDurableObject(env, accountId));
      await waitForEstimationAttempts(accountId, 1);
      const [meal] = await pullRecordsOf("meal");
      correctedAt = saturdayMorningInTokyo - 3_600_000;
      await pushSyncWrites(sessionToken, {
        writes: [updateMealWrite(String(meal?.["id"]), correctedAt)],
      });
      reply();
      await alarm;
    });

    test("推定が完了しても、直した時刻が残ること", async () => {
      expect({
        eatenAts: (await pullRecordsOf("meal")).map(({ eatenAt }) => eatenAt),
        statuses: (await pullRecordsOf("meal_estimation_status")).map(({ status }) => status),
      }).toEqual({ eatenAts: [correctedAt], statuses: ["estimated"] });
    });
  });

  describe("推定が時刻の違う食事を返したとき", () => {
    let sentTextId: string;
    beforeEach(async () => {
      mockCreateEstimationProviderOk({
        identifiedWrittenMeals: {
          meals: [
            { eatenAt: "2026-10-09T19:00", dishes: [bread] },
            { eatenAt: "2026-10-10T07:00", dishes: [udon] },
          ],
        },
      });
      sentTextId = await sendText({
        body: "昨日の夜はパン、今朝はうどん",
        sentAt: saturdayMorningInTokyo,
        timeZone: "Asia/Tokyo",
      });
      await runEstimationAlarm(accountId);
    });

    test("1つ目の食事に1つ目の時刻を書き、2つめの文章の食事を、送った文章の値で作ること", async () => {
      expect(await pullRecordsOf("meal")).toEqual([
        {
          id: expect.any(String),
          eatenAt: Date.UTC(2026, 9, 9, 10, 0),
          eatenAtUtcOffsetSeconds: 32_400,
          sentAt: saturdayMorningInTokyo,
          sentTimeZone: "Asia/Tokyo",
          entryMethod: "written",
          photos: [],
          sentTextId,
        },
        {
          id: expect.any(String),
          eatenAt: Date.UTC(2026, 9, 9, 22, 0),
          eatenAtUtcOffsetSeconds: 32_400,
          sentAt: saturdayMorningInTokyo,
          sentTimeZone: "Asia/Tokyo",
          entryMethod: "written",
          photos: [],
          sentTextId,
        },
      ]);
    });

    test("食事ごとに、その食事の料理と材料が届くこと", async () => {
      const meals = await pullRecordsOf("meal");
      const dishes = await pullRecordsOf("dish");
      const ingredients = await pullRecordsOf("ingredient");
      expect(
        meals.map((meal) =>
          dishes
            .filter((dish) => dish["mealId"] === meal["id"])
            .map((dish) => ({
              name: dish["name"],
              ingredients: ingredients
                .filter((ingredient) => ingredient["dishId"] === dish["id"])
                .map((ingredient) => ingredient["name"]),
            })),
        ),
      ).toEqual([
        [{ name: "トースト", ingredients: ["食パン"] }],
        [{ name: "かけうどん", ingredients: ["うどん"] }],
      ]);
    });

    test("どちらの食事の推定の状態も、推定できたで届くこと", async () => {
      expect(await pullRecordsOf("meal_estimation_status")).toEqual([
        { mealId: expect.any(String), status: "estimated" },
        { mealId: expect.any(String), status: "estimated" },
      ]);
    });
  });

  describe("範囲の外の日時の食事が2つ返り、どちらも送った時刻になるとき", () => {
    beforeEach(async () => {
      mockCreateEstimationProviderOk({
        identifiedWrittenMeals: {
          meals: [
            { eatenAt: "2026-10-10T12:00", dishes: [bread] },
            { eatenAt: "2026-10-10T19:00", dishes: [udon] },
          ],
        },
      });
      await sendText({
        body: "パンとうどん",
        sentAt: saturdayMorningInTokyo,
        timeZone: "Asia/Tokyo",
      });
      await runEstimationAlarm(accountId);
    });

    test("同じ時刻の料理を1つの食事にまとめること", async () => {
      expect({
        meals: (await pullRecordsOf("meal")).map(({ eatenAt }) => eatenAt),
        dishes: (await pullRecordsOf("dish")).map(({ name }) => name),
      }).toEqual({ meals: [saturdayMorningInTokyo], dishes: ["トースト", "かけうどん"] });
    });
  });

  describe("推定で前の日より前に移った食事があり、その日の食事を作る書き込みを送ったとき", () => {
    let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      mockCreateEstimationProviderOk({
        identifiedWrittenMeals: { meals: [{ eatenAt: "2026-10-07T19:00", dishes: [bread] }] },
      });
      await sendText({
        body: "水曜の夜はパン",
        sentAt: saturdayMorningInTokyo,
        timeZone: "Asia/Tokyo",
      });
      await runEstimationAlarm(accountId);
      captureSpy = mockPostHogCaptureEndpointOk();
      // 東京の 2026-10-07 21:00
      await pushSyncWrites(sessionToken, {
        writes: [
          createMealWrite({
            meal: { eatenAt: Date.UTC(2026, 9, 7, 12, 0), eatenAtUtcOffsetSeconds: 32_400 },
          }),
        ],
      });
    });

    test("推定した日の食事に数えて、その日の2回目として送ること", () => {
      expect(
        readPostHogCapturedEvents(captureSpy).find(({ event }) => event === "meal_received")
          ?.properties["meal_count_of_day"],
      ).toBe(2);
    });
  });

  describe("推定の途中で食事を消したとき", () => {
    beforeEach(async () => {
      const { promise: replyAfter, resolve: reply } = Promise.withResolvers<void>();
      mockCreateEstimationProviderOk({
        replyAfter,
        identifiedWrittenMeals: {
          meals: [
            { eatenAt: "2026-10-09T19:00", dishes: [bread] },
            { eatenAt: "2026-10-10T07:00", dishes: [udon] },
          ],
        },
      });
      await sendText({
        body: "パンとうどん",
        sentAt: saturdayMorningInTokyo,
        timeZone: "Asia/Tokyo",
      });
      const alarm = runDurableObjectAlarm(getAccountDurableObject(env, accountId));
      await waitForEstimationAttempts(accountId, 1);
      const [meal] = await pullRecordsOf("meal");
      await pushSyncWrites(sessionToken, { writes: [deleteMealWrite(String(meal?.["id"]))] });
      reply();
      await alarm;
    });

    test("届いた推定を捨て、2つめ以降の食事も時刻も料理も作らないこと", async () => {
      expect({
        meals: await readRows(accountId, "SELECT id FROM meals"),
        createdMeals: await readRows(accountId, "SELECT meal_id FROM estimation_created_meals"),
        eatenAts: await readRows(accountId, "SELECT meal_id FROM meal_eaten_at_estimations"),
        dishes: await readRows(accountId, "SELECT id FROM dishes"),
      }).toEqual({ meals: [], createdMeals: [], eatenAts: [], dishes: [] });
    });
  });

  describe("推定できた文章の食事の料理の名前を直したとき", () => {
    let provider: ReturnType<typeof mockCreateEstimationProviderOk>;
    beforeEach(async () => {
      provider = mockCreateEstimationProviderOk({
        identifiedWrittenMeals: {
          meals: [
            { eatenAt: "2026-10-09T19:00", dishes: [bread] },
            { eatenAt: "2026-10-10T07:00", dishes: [udon] },
          ],
        },
      });
      await sendText({
        body: "パンとうどん",
        sentAt: saturdayMorningInTokyo,
        timeZone: "Asia/Tokyo",
      });
      await runEstimationAlarm(accountId);
      const udonDish = (await pullRecordsOf("dish")).find(({ name }) => name === "かけうどん");
      clock.advance(1000);
      await pushSyncWrites(sessionToken, {
        writes: [updateDishWrite(String(udonDish?.["id"]), { name: "きつねうどん" })],
      });
      await runEstimationAlarm(accountId);
    });

    test("写真を渡さず、名前だけで推定し直すこと", () => {
      expect(
        readIdentifyDishesRequests(provider).map(({ photos, target }) => ({
          photoCount: photos.length,
          target,
        })),
      ).toEqual([
        {
          photoCount: 0,
          target: {
            type: "dish",
            dish: { name: "きつねうどん", correctedIngredients: [], correctedQuantity: undefined },
          },
        },
      ]);
    });

    test("推定し直した料理が届き、推定の状態が推定できたになること", async () => {
      expect({
        dishes: (await pullRecordsOf("dish")).map(({ name }) => name),
        statuses: (await pullRecordsOf("dish_estimation_status")).map(({ status }) => status),
      }).toEqual({ dishes: ["トースト", "きつねうどん"], statuses: ["estimated"] });
    });
  });

  describe("利用状況を送る人の文章の食事を、2つの食事に推定したとき", () => {
    let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      mockCreateEstimationProviderOk({
        identifiedWrittenMeals: {
          meals: [
            { eatenAt: "2026-10-09T19:00", dishes: [bread] },
            { eatenAt: "2026-10-10T07:00", dishes: [udon] },
          ],
        },
      });
      captureSpy = mockPostHogCaptureEndpointOk();
      await sendText({
        body: "パンとうどん",
        sentAt: saturdayMorningInTokyo,
        timeZone: "Asia/Tokyo",
      });
      await runEstimationAlarm(accountId);
    });

    test("推定ごとの出来事を、きっかけを文章にし、両方の食事の料理と材料を数えて送ること", () => {
      expect(
        readPostHogCapturedEvents(captureSpy)
          .filter(({ event }) => event === "estimation_ended")
          .map(({ properties }) => ({
            trigger: properties["trigger"],
            dishCount: properties["dish_count"],
            ingredientCount: properties["ingredient_count"],
          })),
      ).toEqual([{ trigger: "text", dishCount: 2, ingredientCount: 2 }]);
    });
  });
});
