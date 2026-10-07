import { runDurableObjectAlarm } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { generateRecordId } from "../../domain/record-id";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { enableUsageEventSending } from "../../http/sync-routes/testing/enable-usage-event-sending";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import { signInTestAccount } from "../../http/testing";
import { mockPhotosBucketGetError } from "../../meal/durable-object/testing/photos-bucket.mock";
import { deleteMealWrite } from "../../meal/http/testing/delete-meal-write";
import { mockCaptureExceptionOk } from "../../observability/capture-exception.mock";
import { mockSetUserOk } from "../../observability/set-user.mock";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { EstimationProviderBadRequestError } from "../domain/estimation-provider-bad-request-error";
import { EstimationProviderError } from "../domain/estimation-provider-error";
import { EstimationProviderTimedOutError } from "../domain/estimation-provider-timed-out-error";
import {
  mockCreateEstimationProviderError,
  mockCreateEstimationProviderOk,
} from "../durable-object/create-estimation-provider/create-estimation-provider.mock";
import { recordPhotographedMeal } from "./testing/record-photographed-meal";
import { runEstimationAlarm } from "./testing/run-estimation-alarm";
import { useFakeClock } from "./testing/use-fake-clock";
import { waitForEstimationAttempts } from "./testing/wait-for-estimation-attempts";
import { beforeEach, describe, expect, test, vi } from "vitest";

describe("推定", () => {
  let accountId: string;
  let sessionToken: string;
  let pullChangesAfter: (afterSequence: number) => Promise<PullResult["changes"]>;
  let pullLastSequence: () => Promise<number>;
  let pullStatus: (mealId: string) => Promise<unknown>;
  let clock: ReturnType<typeof useFakeClock>;
  // 次に試みる時刻を過ぎるまで時計を進めて、アラームを動かす
  let runAlarmLater: () => Promise<void>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
    clock = useFakeClock(Date.now() + 86_400_000);
    pullChangesAfter = async (afterSequence) =>
      (await (await pullSyncChanges(sessionToken, { afterSequence })).json<PullResult>()).changes;
    pullLastSequence = async () =>
      (await (await pullSyncChanges(sessionToken)).json<PullResult>()).nextAfterSequence;
    pullStatus = async (mealId) =>
      (await pullChangesAfter(0)).find(
        ({ kind, recordId }) => kind === "meal_estimation_status" && recordId === mealId,
      )?.record;
    runAlarmLater = async () => {
      clock.advance(3_600_000);
      await runEstimationAlarm(accountId);
    };
  });

  describe("提供元が料理ありで答えたとき", () => {
    let mealId: string;
    let changes: PullResult["changes"];
    let dishIds: string[];
    beforeEach(async () => {
      mockCreateEstimationProviderOk();
      mealId = await recordPhotographedMeal(sessionToken);
      const sequenceBeforeAlarm = await pullLastSequence();
      await runEstimationAlarm(accountId);
      changes = await pullChangesAfter(sequenceBeforeAlarm);
      dishIds = changes.filter(({ kind }) => kind === "dish").map(({ recordId }) => recordId);
    });

    test("取りに行くと、料理と材料の変更のあとに、推定できたの推定の状態が返ること", () => {
      expect(
        changes.map(({ kind, record }) => (kind === "meal_estimation_status" ? record : kind)),
      ).toEqual([
        "dish",
        "dish",
        "ingredient",
        "ingredient",
        "ingredient",
        { mealId, status: "estimated" },
      ]);
    });

    test("料理を、食事の中の並び順と版 1 で返すこと", () => {
      expect(changes.filter(({ kind }) => kind === "dish").map(({ record }) => record)).toEqual([
        {
          id: expect.any(String),
          mealId,
          name: "親子丼",
          quantity: 1,
          unit: "杯",
          quantitySource: "estimated",
          positionInMeal: 0,
          version: 1,
        },
        {
          id: expect.any(String),
          mealId,
          name: "緑茶",
          quantity: 1,
          unit: "本",
          quantitySource: "estimated",
          positionInMeal: 1,
          version: 1,
        },
      ]);
    });

    test("材料を、料理の中の並び順と、栄養の出どころと、基準あたりの栄養の値で返すこと", () => {
      expect(
        changes.filter(({ kind }) => kind === "ingredient").map(({ record }) => record),
      ).toEqual([
        {
          id: expect.any(String),
          dishId: dishIds[0],
          name: "鶏もも肉",
          quantity: 80,
          unit: "g",
          edibleGramsPerUnit: 1,
          positionInDish: 0,
          quantitySource: "estimated",
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
          id: expect.any(String),
          dishId: dishIds[0],
          name: "ご飯",
          quantity: 200,
          unit: "g",
          edibleGramsPerUnit: 1,
          positionInDish: 1,
          quantitySource: "estimated",
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
        {
          id: expect.any(String),
          dishId: dishIds[1],
          name: "緑茶",
          quantity: 1,
          unit: "本",
          edibleGramsPerUnit: 500,
          positionInDish: 0,
          quantitySource: "estimated",
          nutrientSource: { type: "nutrition_label", labelBasisGrams: 100 },
          nutrients: { energy_kcal: 0, protein_g: 0, salt_equivalent_g: 0.02 },
        },
      ]);
    });
  });

  describe("料理ありで推定し、本番のサーバーで利用状況を送る人のとき", () => {
    let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      mockCreateEstimationProviderOk();
      await recordPhotographedMeal(sessionToken);
      clock.advance(30_000);
      captureSpy = mockPostHogCaptureEndpointOk();
      await runEstimationAlarm(accountId);
    });

    test("試みを終えた出来事を、①と②のトークンとともに送ること", () => {
      expect(
        readPostHogCapturedEvents(captureSpy).filter(
          ({ event }) => event === "estimation_attempt_ended",
        ),
      ).toEqual([
        {
          event: "estimation_attempt_ended",
          distinct_id: accountId,
          properties: {
            result: "succeeded",
            identify_dishes_input_tokens: 1500,
            identify_dishes_output_tokens: 400,
            match_ingredients_input_tokens: 800,
            match_ingredients_output_tokens: 200,
            $geoip_disable: true,
          },
        },
      ]);
    });

    test("推定ごとの出来事を、料理と材料の数と出どころの内訳とともに送ること", () => {
      expect(
        readPostHogCapturedEvents(captureSpy).filter(({ event }) => event === "estimation_ended"),
      ).toEqual([
        {
          event: "estimation_ended",
          distinct_id: accountId,
          properties: {
            trigger: "photo",
            final_status: "estimated",
            retry_count: 0,
            dish_count: 2,
            ingredient_count: 3,
            nutrition_label_ingredient_count: 1,
            food_composition_ingredient_count: 1,
            estimated_ingredient_count: 1,
            seconds_from_received_to_ended: 30,
            provider_error_types: [],
            $geoip_disable: true,
          },
        },
      ]);
    });
  });

  describe("提供元が料理なしと答えたとき", () => {
    let mealId: string;
    let changes: PullResult["changes"];
    beforeEach(async () => {
      mockCreateEstimationProviderOk({ identifiedDishes: { dishes: [] } });
      mealId = await recordPhotographedMeal(sessionToken);
      const sequenceBeforeAlarm = await pullLastSequence();
      await runEstimationAlarm(accountId);
      changes = await pullChangesAfter(sequenceBeforeAlarm);
    });

    test("取りに行くと、料理なしの推定の状態だけが返ること", () => {
      expect(changes.map(({ kind, record }) => ({ kind, record }))).toEqual([
        { kind: "meal_estimation_status", record: { mealId, status: "no_dishes" } },
      ]);
    });
  });

  describe("提供元がエラーを返したとき", () => {
    let mealId: string;
    let providerResponseError: Error;
    let setUserSpy: ReturnType<typeof mockSetUserOk>;
    let captureExceptionSpy: ReturnType<typeof mockCaptureExceptionOk>;
    let logSpy: ReturnType<typeof vi.spyOn>;
    beforeEach(async () => {
      providerResponseError = new Error("Overloaded");
      mockCreateEstimationProviderError(
        new EstimationProviderError({
          errorType: "overloaded_error",
          cause: providerResponseError,
        }),
      );
      mealId = await recordPhotographedMeal(sessionToken);
      setUserSpy = mockSetUserOk();
      captureExceptionSpy = mockCaptureExceptionOk();
      logSpy = vi.spyOn(console, "log");
      await runEstimationAlarm(accountId);
    });

    test("推定中のまま、やり直しを待つこと", async () => {
      expect(await pullStatus(mealId)).toEqual({ mealId, status: "estimating" });
    });

    test("試みの結果と、提供元のエラーの種類を書くこと", async () => {
      expect(
        await readRows(
          accountId,
          "SELECT result, error_type FROM estimation_attempt_results LEFT JOIN estimation_attempt_errors USING (estimation_attempt_id)",
        ),
      ).toEqual([{ result: "provider_error", error_type: "overloaded_error" }]);
    });

    test("提供元の応答のエラーを、包まずにアカウント ID を付けて Sentry に送ること", () => {
      expect({
        user: setUserSpy.mock.calls.at(-1)?.[0],
        exceptions: captureExceptionSpy.mock.calls.map(([error]) => error),
      }).toEqual({ user: { id: accountId }, exceptions: [providerResponseError] });
    });

    test("アラームの呼び出しのログに、失敗した段と提供元のエラーの種類を出すこと", () => {
      expect(logSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          accountId,
          route: "alarm",
          estimationAttempts: [
            {
              result: "provider_error",
              failedStage: "identify_dishes",
              errorType: "overloaded_error",
            },
          ],
        }),
      );
    });

    describe("6回やり直しても通らなかったとき", () => {
      beforeEach(async () => {
        for (let retry = 0; retry < 6; retry += 1) {
          await runAlarmLater();
        }
      });

      test("推定できなかったにすること", async () => {
        expect(await pullStatus(mealId)).toEqual({ mealId, status: "failed" });
      });

      test("試みを7つで止めること", async () => {
        await runAlarmLater();
        expect(await readRows(accountId, "SELECT id FROM estimation_attempts")).toHaveLength(7);
      });
    });

    describe("やり直しで料理ありと答えたとき", () => {
      beforeEach(async () => {
        mockCreateEstimationProviderOk();
        await runAlarmLater();
      });

      test("推定できたにすること", async () => {
        expect(await pullStatus(mealId)).toEqual({ mealId, status: "estimated" });
      });
    });
  });

  describe("提供元が 400 を返したとき", () => {
    let mealId: string;
    beforeEach(async () => {
      mockCreateEstimationProviderError(
        new EstimationProviderBadRequestError({ errorType: "invalid_request_error" }),
      );
      mealId = await recordPhotographedMeal(sessionToken);
      await runEstimationAlarm(accountId);
      await runAlarmLater();
    });

    test("やり直さずに推定できなかったにすること", async () => {
      expect({
        status: await pullStatus(mealId),
        attempts: await readRows(accountId, "SELECT id FROM estimation_attempts"),
      }).toEqual({ status: { mealId, status: "failed" }, attempts: [{ id: expect.any(String) }] });
    });
  });

  describe("提供元の呼び出しが時間切れになったとき", () => {
    let mealId: string;
    beforeEach(async () => {
      mockCreateEstimationProviderError(new EstimationProviderTimedOutError());
      mealId = await recordPhotographedMeal(sessionToken);
      await runEstimationAlarm(accountId);
    });

    test("時間切れを試みの結果に書き、推定中のままやり直しを待つこと", async () => {
      expect({
        status: await pullStatus(mealId),
        results: await readRows(accountId, "SELECT result FROM estimation_attempt_results"),
      }).toEqual({ status: { mealId, status: "estimating" }, results: [{ result: "timed_out" }] });
    });
  });

  describe("応答が確かめに通らないまま、試みが7つになったとき", () => {
    let mealId: string;
    beforeEach(async () => {
      mockCreateEstimationProviderOk({
        identifiedDishes: {
          dishes: [{ name: "親子丼", quantity: 0, unit: "杯", ingredients: [] }],
        },
      });
      mealId = await recordPhotographedMeal(sessionToken);
      await runEstimationAlarm(accountId);
      for (let retry = 0; retry < 6; retry += 1) {
        await runAlarmLater();
      }
    });

    test("どの試みも確かめに通らないと書き、推定できなかったにすること", async () => {
      expect({
        status: await pullStatus(mealId),
        results: await readRows(
          accountId,
          "SELECT DISTINCT result FROM estimation_attempt_results",
        ),
      }).toEqual({
        status: { mealId, status: "failed" },
        results: [{ result: "invalid_response" }],
      });
    });
  });

  describe("② の答えの食品番号が、成分表の候補に無いとき", () => {
    beforeEach(async () => {
      mockCreateEstimationProviderOk({
        matchIngredients: ({ ingredients }) => ({
          ingredients: ingredients.map(() => ({
            source: "food_composition",
            foodNumber: "99999",
          })),
        }),
      });
      await recordPhotographedMeal(sessionToken);
      await runEstimationAlarm(accountId);
    });

    test("確かめに通らない試みにすること", async () => {
      expect(await readRows(accountId, "SELECT result FROM estimation_attempt_results")).toEqual([
        { result: "invalid_response" },
      ]);
    });
  });

  describe("① は通り ② で提供元がエラーを返したとき、本番のサーバーで利用状況を送る人なら", () => {
    let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      mockCreateEstimationProviderError(new EstimationProviderError({ errorType: "api_error" }), {
        failingCall: "match_ingredients",
      });
      await recordPhotographedMeal(sessionToken);
      captureSpy = mockPostHogCaptureEndpointOk();
      await runEstimationAlarm(accountId);
    });

    test("試みを終えた出来事を、① のトークンとともに送ること", () => {
      expect(
        readPostHogCapturedEvents(captureSpy).filter(
          ({ event }) => event === "estimation_attempt_ended",
        ),
      ).toEqual([
        {
          event: "estimation_attempt_ended",
          distinct_id: accountId,
          properties: {
            result: "provider_error",
            identify_dishes_input_tokens: 1500,
            identify_dishes_output_tokens: 400,
            $geoip_disable: true,
          },
        },
      ]);
    });
  });

  describe("提供元の呼び出し中に止まったとき", () => {
    let mealId: string;
    beforeEach(async () => {
      mockCreateEstimationProviderOk({ replyAfter: new Promise(() => undefined) });
      mealId = await recordPhotographedMeal(sessionToken);
      // 止まったアラームは終わらないので待たない
      void runDurableObjectAlarm(getAccountDurableObject(env, accountId));
      await waitForEstimationAttempts(accountId, 1);
    });

    describe("次に試みる時刻を過ぎて、提供元が料理ありで答えたとき", () => {
      beforeEach(async () => {
        mockCreateEstimationProviderOk();
        await runAlarmLater();
      });

      test("止まった試みも数えて、2つ目の試みで推定できたにすること", async () => {
        expect({
          status: await pullStatus(mealId),
          attempts: await readRows(accountId, "SELECT id FROM estimation_attempts"),
        }).toEqual({
          status: { mealId, status: "estimated" },
          attempts: [{ id: expect.any(String) }, { id: expect.any(String) }],
        });
      });
    });
  });

  describe("6回の試みが提供元のエラーで、7つ目の試みの呼び出し中に止まったとき", () => {
    let mealId: string;
    beforeEach(async () => {
      mockCreateEstimationProviderError(new EstimationProviderError({ errorType: "api_error" }));
      mealId = await recordPhotographedMeal(sessionToken);
      await runEstimationAlarm(accountId);
      for (let retry = 0; retry < 5; retry += 1) {
        await runAlarmLater();
      }
      mockCreateEstimationProviderOk({ replyAfter: new Promise(() => undefined) });
      clock.advance(3_600_000);
      void runDurableObjectAlarm(getAccountDurableObject(env, accountId));
      await waitForEstimationAttempts(accountId, 7);
      mockCreateEstimationProviderOk();
      await runAlarmLater();
    });

    test("もう呼ばずに推定できなかったにすること", async () => {
      expect({
        status: await pullStatus(mealId),
        attempts: (await readRows(accountId, "SELECT id FROM estimation_attempts")).length,
      }).toEqual({ status: { mealId, status: "failed" }, attempts: 7 });
    });
  });

  describe("提供元の呼び出し中に食事を消したとき", () => {
    let mealId: string;
    let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      const { promise: replyAfter, resolve: reply } = Promise.withResolvers<void>();
      mockCreateEstimationProviderOk({ replyAfter });
      mealId = await recordPhotographedMeal(sessionToken);
      clock.advance(30_000);
      const alarm = runDurableObjectAlarm(getAccountDurableObject(env, accountId));
      await waitForEstimationAttempts(accountId, 1);
      captureSpy = mockPostHogCaptureEndpointOk();
      await pushSyncWrites(sessionToken, { writes: [deleteMealWrite(mealId)] });
      reply();
      await alarm;
    });

    test("試みの結果だけを書き、料理・材料・完了を書かないこと", async () => {
      expect({
        results: await readRows(accountId, "SELECT result FROM estimation_attempt_results"),
        dishes: await readRows(accountId, "SELECT id FROM dishes"),
        completions: await readRows(accountId, "SELECT * FROM estimation_completions"),
      }).toEqual({ results: [{ result: "succeeded" }], dishes: [], completions: [] });
    });

    test("推定の行を残し、回数を戻さないこと", async () => {
      expect(await readRows(accountId, "SELECT id FROM estimations")).toHaveLength(1);
    });

    test("推定ごとの出来事を「食事が消えた」で送り、試みを終えた出来事も送ること", () => {
      expect(
        readPostHogCapturedEvents(captureSpy)
          .filter(({ event }) => event !== "meal_received")
          .map(({ event, properties }) => ({
            event,
            finalStatus: properties["final_status"],
            result: properties["result"],
          })),
      ).toEqual([
        { event: "estimation_ended", finalStatus: "meal_deleted", result: undefined },
        { event: "estimation_attempt_ended", finalStatus: undefined, result: "succeeded" },
      ]);
    });
  });

  describe("推定できた食事を消したとき", () => {
    let mealId: string;
    let dishIds: string[];
    let ingredientIds: string[];
    let deletedChanges: PullResult["changes"];
    beforeEach(async () => {
      mockCreateEstimationProviderOk();
      mealId = await recordPhotographedMeal(sessionToken);
      await runEstimationAlarm(accountId);
      const sequenceBeforeDeletion = await pullLastSequence();
      const estimatedChanges = await pullChangesAfter(0);
      dishIds = estimatedChanges
        .filter(({ kind }) => kind === "dish")
        .map(({ recordId }) => recordId);
      ingredientIds = estimatedChanges
        .filter(({ kind }) => kind === "ingredient")
        .map(({ recordId }) => recordId);
      await pushSyncWrites(sessionToken, { writes: [deleteMealWrite(mealId)] });
      deletedChanges = await pullChangesAfter(sequenceBeforeDeletion);
    });

    test("取りに行くと、食事・推定の状態・料理・材料の削除の印が1つずつ返ること", () => {
      expect(
        deletedChanges.map(({ kind, recordId, record }) => ({ kind, recordId, record })),
      ).toEqual([
        { kind: "meal_deletion", recordId: mealId, record: {} },
        { kind: "meal_estimation_status_deletion", recordId: mealId, record: {} },
        ...dishIds.map((recordId) => ({ kind: "dish_deletion", recordId, record: {} })),
        ...ingredientIds.map((recordId) => ({
          kind: "ingredient_deletion",
          recordId,
          record: {},
        })),
      ]);
    });

    test("料理と材料の行を消し、栄養の値と出どころも消すこと", async () => {
      expect({
        dishes: await readRows(accountId, "SELECT id FROM dishes"),
        ingredients: await readRows(accountId, "SELECT id FROM ingredients"),
        nutrients: await readRows(accountId, "SELECT id FROM ingredient_nutrients"),
        foodComposition: await readRows(accountId, "SELECT * FROM food_composition_ingredients"),
      }).toEqual({ dishes: [], ingredients: [], nutrients: [], foodComposition: [] });
    });

    test("料理と材料の削除の印を、消した書き込みの控えつきで書くこと", async () => {
      expect({
        dishes: await readRows(
          accountId,
          "SELECT count(*) AS count FROM dish_deletions JOIN sync_write_receipts ON sync_write_receipts.id = dish_deletions.sync_write_receipt_id WHERE sync_write_receipts.kind = 'delete'",
        ),
        ingredients: await readRows(
          accountId,
          "SELECT count(*) AS count FROM ingredient_deletions JOIN sync_write_receipts ON sync_write_receipts.id = ingredient_deletions.sync_write_receipt_id WHERE sync_write_receipts.kind = 'delete'",
        ),
      }).toEqual({ dishes: [{ count: 2 }], ingredients: [{ count: 3 }] });
    });
  });

  describe("写真を R2 から読めなかったとき", () => {
    let alarm: Promise<boolean>;
    let logSpy: ReturnType<typeof vi.spyOn>;
    beforeEach(async () => {
      mockCreateEstimationProviderOk();
      await recordPhotographedMeal(sessionToken);
      mockPhotosBucketGetError(new Error("R2 に届かない"));
      logSpy = vi.spyOn(console, "log");
      alarm = runEstimationAlarm(accountId);
    });

    test("アラームを例外にし、ログに失敗した段を出すこと", async () => {
      await expect(alarm).rejects.toThrow("推定の試みが途中で止まった");
      expect(logSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          route: "alarm",
          error: "EstimationAttemptStoppedError",
          failedStage: "read_photos",
        }),
      );
    });

    test("試みを、結果の無いまま残すこと", async () => {
      await alarm.catch(() => undefined);
      expect({
        attempts: (await readRows(accountId, "SELECT id FROM estimation_attempts")).length,
        results: await readRows(accountId, "SELECT * FROM estimation_attempt_results"),
      }).toEqual({ attempts: 1, results: [] });
    });
  });
});
