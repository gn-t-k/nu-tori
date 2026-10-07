import { generateRecordId } from "../../domain/record-id";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { mockCreateEstimationProviderOk } from "../../estimation/durable-object/create-estimation-provider/create-estimation-provider.mock";
import { recordPhotographedMeal } from "../../estimation/http/testing/record-photographed-meal";
import { runEstimationAlarm } from "../../estimation/http/testing/run-estimation-alarm";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites, type PushResults } from "../../http/sync-routes/testing/push-sync-writes";
import { requireLastSequence } from "../../http/sync-routes/testing/require-last-sequence";
import { signInTestAccount } from "../../http/testing";
import { deleteDishWrite } from "../../dish/http/testing/delete-dish-write";
import { enableUsageEventSending } from "../../http/sync-routes/testing/enable-usage-event-sending";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { updateIngredientWrite } from "./testing/update-ingredient-write";
import { beforeEach, describe, expect, test } from "vitest";

describe("材料の同期", () => {
  let accountId: string;
  let sessionToken: string;
  let pullChangesAfter: (afterSequence: number) => Promise<PullResult["changes"]>;
  // 推定した親子丼と、その材料の鶏もも肉（推定した量は 80 g）
  let dishId: string;
  let ingredientId: string;
  let lastSequence: number;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
    useFakeClock(Date.now() + 86_400_000);
    pullChangesAfter = async (afterSequence) =>
      (await (await pullSyncChanges(sessionToken, { afterSequence })).json<PullResult>()).changes;
    mockCreateEstimationProviderOk();
    await recordPhotographedMeal(sessionToken);
    await runEstimationAlarm(accountId);
    const estimated = await pullChangesAfter(0);
    const ingredient = estimated.find(
      ({ kind, record }) => kind === "ingredient" && record["name"] === "鶏もも肉",
    );
    const ingredientDishId = ingredient?.record["dishId"];
    if (ingredient === undefined || typeof ingredientDishId !== "string") {
      throw new Error("推定で鶏もも肉ができていない");
    }
    ingredientId = ingredient.recordId;
    dishId = ingredientDishId;
    lastSequence = requireLastSequence(estimated);
  });

  describe("推定した材料の量を直す書き込みを送ったとき", () => {
    let write: ReturnType<typeof updateIngredientWrite>;
    let results: PushResults["results"];
    beforeEach(async () => {
      write = updateIngredientWrite(ingredientId, 120);
      ({ results } = await (
        await pushSyncWrites(sessionToken, { writes: [write] })
      ).json<PushResults>());
    });

    test("当てたと返すこと", () => {
      expect(results).toEqual([{ writeId: write.id, result: "applied" }]);
    });

    test("取りに行くと、直した量と出どころが直したの材料と、版の上がった料理が返ること", async () => {
      const changes = await pullChangesAfter(lastSequence);
      expect(
        changes.map(({ kind, recordId, record }) => ({
          kind,
          recordId,
          quantity: record["quantity"],
          quantitySource: record["quantitySource"],
          version: record["version"],
        })),
      ).toEqual([
        {
          kind: "ingredient",
          recordId: ingredientId,
          quantity: 120,
          quantitySource: "corrected",
          version: undefined,
        },
        {
          kind: "dish",
          recordId: dishId,
          quantity: 1,
          quantitySource: "estimated",
          version: 2,
        },
      ]);
    });

    describe("同じ材料をもう一度別の量に直したとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, { writes: [updateIngredientWrite(ingredientId, 90)] });
      });

      test("取りに行くと、あとに受け取った量の材料と、もう一度版の上がった料理が返ること", async () => {
        const changes = await pullChangesAfter(lastSequence);
        expect({
          ingredient: changes.findLast(({ kind }) => kind === "ingredient")?.record["quantity"],
          dishVersion: changes.findLast(({ kind }) => kind === "dish")?.record["version"],
        }).toEqual({ ingredient: 90, dishVersion: 3 });
      });
    });

    describe("今の量と同じ量に直す書き込みを送ったとき", () => {
      let sequenceBefore: number;
      let sameResults: PushResults["results"];
      beforeEach(async () => {
        sequenceBefore = requireLastSequence(await pullChangesAfter(0));
        ({ results: sameResults } = await (
          await pushSyncWrites(sessionToken, { writes: [updateIngredientWrite(ingredientId, 120)] })
        ).json<PushResults>());
      });

      test("当てたと返すこと", () => {
        expect(sameResults.map(({ result }) => result)).toEqual(["applied"]);
      });

      test("変更を足さないこと", async () => {
        expect(await pullChangesAfter(sequenceBefore)).toEqual([]);
      });
    });
  });

  describe("量が 0 の書き込みを送ったとき", () => {
    let results: PushResults["results"];
    beforeEach(async () => {
      ({ results } = await (
        await pushSyncWrites(sessionToken, { writes: [updateIngredientWrite(ingredientId, 0)] })
      ).json<PushResults>());
    });

    test("範囲の外として受け付けず、今の値に推定した量の材料を添えること", () => {
      expect(
        results.map(({ result, rejectionReason, current }) => ({
          result,
          rejectionReason,
          status: current?.status,
          quantity: current?.change?.record["quantity"],
        })),
      ).toEqual([
        { result: "rejected", rejectionReason: "out_of_range", status: "value", quantity: 80 },
      ]);
    });
  });

  describe("知らない材料の量を直す書き込みを送ったとき", () => {
    let results: PushResults["results"];
    beforeEach(async () => {
      ({ results } = await (
        await pushSyncWrites(sessionToken, {
          writes: [updateIngredientWrite(generateRecordId(), 100)],
        })
      ).json<PushResults>());
    });

    test("直す先が無いとして受け付けず、今の値に無いことを添えること", () => {
      expect(
        results.map(({ result, rejectionReason, current }) => ({
          result,
          rejectionReason,
          current,
        })),
      ).toEqual([
        { result: "rejected", rejectionReason: "record_not_found", current: { status: "absent" } },
      ]);
    });
  });

  describe("料理ごと消した材料の量を直す書き込みを送ったとき", () => {
    let results: PushResults["results"];
    beforeEach(async () => {
      ({ results } = await (
        await pushSyncWrites(sessionToken, {
          writes: [deleteDishWrite(dishId), updateIngredientWrite(ingredientId, 100)],
        })
      ).json<PushResults>());
    });

    test("直す先が無いとして受け付けず、今の値に削除の印を添えること", () => {
      expect(
        results.map(({ result, rejectionReason, current }) => ({
          result,
          rejectionReason,
          status: current?.status,
        }))[1],
      ).toEqual({ result: "rejected", rejectionReason: "record_not_found", status: "deleted" });
    });
  });

  describe("本番のサーバーで", () => {
    let fetchSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      fetchSpy = mockPostHogCaptureEndpointOk();
    });

    describe("推定した材料の量を直したとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, { writes: [updateIngredientWrite(ingredientId, 120)] });
      });

      test("直した量 ÷ 推定の量と、材料であること、写真の食事であること、材料の栄養の出どころを PostHog に送ること", () => {
        expect(readPostHogCapturedEvents(fetchSpy)).toEqual([
          {
            event: "estimated_quantity_corrected",
            distinct_id: accountId,
            properties: {
              target: "ingredient",
              meal_input: "photo",
              ingredient_nutrient_source: "food_composition",
              ratio: 1.5,
              $geoip_disable: true,
            },
          },
        ]);
      });

      describe("直した材料をもう一度直したとき", () => {
        beforeEach(async () => {
          fetchSpy.mockClear();
          await pushSyncWrites(sessionToken, { writes: [updateIngredientWrite(ingredientId, 90)] });
        });

        test("送らないこと", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
        });
      });
    });
  });
});
