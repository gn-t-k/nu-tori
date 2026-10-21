import { beforeEach, describe, expect, test } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { updateDishWrite } from "../../dish/http/testing/update-dish-write";
import { addDays } from "../../domain/add-days";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { generateRecordId } from "../../domain/record-id";
import { enableUsageEventSending } from "../../http/sync-routes/testing/enable-usage-event-sending";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import { signInTestAccount } from "../../http/testing";
import { putMealPhoto } from "../../http/meal-photo-routes/testing/put-meal-photo";
import { createMealWrite } from "../../meal/http/testing/create-meal-write";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { markTestUser } from "../../subscription-status/http/testing/mark-test-user";
import { placeFreeTrialLastDay } from "../../subscription-status/http/testing/place-free-trial-last-day";
import { mockCreateEstimationProviderOk } from "../durable-object/create-estimation-provider/create-estimation-provider.mock";
import { insertCountedEstimations } from "./testing/insert-counted-estimations";
import { recordEstimatedMeal } from "./testing/record-estimated-meal";
import { recordPhotographedMeal } from "./testing/record-photographed-meal";
import { runEstimationAlarm } from "./testing/run-estimation-alarm";
import { useFakeClock } from "./testing/use-fake-clock";

// 推定を始めるときの、使えるかの判定（#647 の「推定と返事」）。同期の要求は Asia/Tokyo で送る
describe("サブスクリプション切れのときの推定", () => {
  let accountId: string;
  let sessionToken: string;
  let clock: ReturnType<typeof useFakeClock>;
  let today: string;
  let pullStatusesOf: (kind: string) => Promise<Record<string, unknown>[]>;
  let countRows: (table: string) => Promise<number>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
    clock = useFakeClock(Date.now() + 86_400_000);
    today = computeCalendarDayInTimeZone(new Date(), "Asia/Tokyo");
    mockCreateEstimationProviderOk();
    pullStatusesOf = async (kind) =>
      (await (await pullSyncChanges(sessionToken)).json<PullResult>()).changes
        .filter((change) => change.kind === kind)
        .map(({ record }) => record);
    countRows = async (table) => (await readRows(accountId, `SELECT * FROM ${table}`)).length;
  });

  describe("無料体験が終わったアカウントが、写真の食事を送ったとき", () => {
    let mealId: string;
    let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await placeFreeTrialLastDay(accountId, addDays(today, -10));
      await enableUsageEventSending(accountId);
      mealId = await recordPhotographedMeal(sessionToken);
      captureSpy = mockPostHogCaptureEndpointOk();
      await runEstimationAlarm(accountId);
    });

    test("推定を始めず、予定に保留を書くこと", async () => {
      expect({
        estimations: await countRows("estimations"),
        holds: await countRows("estimation_holds"),
      }).toEqual({ estimations: 0, holds: 1 });
    });

    test("推定の状態がサブスクリプションを待っているで届くこと", async () => {
      expect(await pullStatusesOf("meal_estimation_status")).toEqual([
        { mealId, status: "awaiting_subscription" },
      ]);
    });

    test("保留した出来事を、理由をサブスクリプション切れにして送ること", () => {
      expect(
        readPostHogCapturedEvents(captureSpy).filter(
          ({ event }) => event === "estimation_deferred",
        ),
      ).toEqual([
        {
          event: "estimation_deferred",
          distinct_id: accountId,
          properties: { reason: "subscription_expired", $geoip_disable: true },
        },
      ]);
    });

    describe("そのあと別の食事を送ったとき", () => {
      beforeEach(async () => {
        clock.advance(1000);
        await recordPhotographedMeal(sessionToken);
        await runEstimationAlarm(accountId);
      });

      test("保留した予定を待っている予定として拾い直さないこと", async () => {
        expect(await countRows("estimation_holds")).toBe(2);
      });
    });

    describe("そのあとテストユーザーの旗を立て、別の食事を送ったとき", () => {
      beforeEach(async () => {
        await markTestUser(accountId);
        clock.advance(1000);
        await recordPhotographedMeal(sessionToken);
        await runEstimationAlarm(accountId);
      });

      test("保留した食事も、今日の分として推定すること", async () => {
        expect(
          await readRows(
            accountId,
            `SELECT s.counted_on FROM estimations e
             JOIN estimation_schedules s ON s.id = e.estimation_schedule_id
             JOIN meal_estimation_schedules m ON m.estimation_schedule_id = s.id
             WHERE m.meal_id = '${mealId}'`,
          ),
        ).toEqual([{ counted_on: today }]);
      });

      test("保留した食事の推定の状態が推定できたで届くこと", async () => {
        expect(
          (await pullStatusesOf("meal_estimation_status")).find(
            (record) => record["mealId"] === mealId,
          ),
        ).toEqual({ mealId, status: "estimated" });
      });
    });

    describe("そのあとテストユーザーの旗を立て、今日の推定を使い切ってから別の食事を送ったとき", () => {
      beforeEach(async () => {
        await markTestUser(accountId);
        await insertCountedEstimations(accountId, today, 15);
        clock.advance(1000);
        await recordPhotographedMeal(sessionToken);
        await runEstimationAlarm(accountId);
      });

      test("保留した食事を翌日に推定にすること", async () => {
        expect(
          (await pullStatusesOf("meal_estimation_status")).find(
            (record) => record["mealId"] === mealId,
          ),
        ).toEqual({ mealId, status: "deferred_to_next_day" });
      });
    });
  });

  describe("無料体験の最後の日に撮った食事が", () => {
    let mealId: string;
    let sendMealEatenYesterday: () => Promise<void>;
    beforeEach(() => {
      mealId = generateRecordId();
      sendMealEatenYesterday = async () => {
        const photoId = generateRecordId();
        await pushSyncWrites(sessionToken, {
          writes: [
            createMealWrite({
              meal: { id: mealId, eatenAt: Date.now() - 86_400_000, photos: [{ id: photoId }] },
            }),
          ],
        });
        await putMealPhoto(sessionToken, photoId);
        await runEstimationAlarm(accountId);
      };
    });

    describe("次の日に届いたとき", () => {
      beforeEach(async () => {
        await placeFreeTrialLastDay(accountId, addDays(today, -1));
        await sendMealEatenYesterday();
      });

      test("推定の状態がサブスクリプションを待っているで届くこと", async () => {
        expect(await pullStatusesOf("meal_estimation_status")).toEqual([
          { mealId, status: "awaiting_subscription" },
        ]);
      });
    });

    describe("最後の日のうちに届いたとき", () => {
      beforeEach(async () => {
        await placeFreeTrialLastDay(accountId, today);
        await sendMealEatenYesterday();
      });

      test("推定すること", async () => {
        expect(await pullStatusesOf("meal_estimation_status")).toEqual([
          { mealId, status: "estimated" },
        ]);
      });
    });
  });

  describe("無料体験が終わったテストユーザーが、写真の食事を送ったとき", () => {
    beforeEach(async () => {
      await placeFreeTrialLastDay(accountId, addDays(today, -10));
      await markTestUser(accountId);
      await recordPhotographedMeal(sessionToken);
      await runEstimationAlarm(accountId);
    });

    test("推定すること", async () => {
      expect((await pullStatusesOf("meal_estimation_status")).map(({ status }) => status)).toEqual([
        "estimated",
      ]);
    });
  });

  describe("無料体験のあいだに推定した料理の名前を、無料体験が終わってから直したとき", () => {
    let dishId: string;
    beforeEach(async () => {
      const estimated = await recordEstimatedMeal(accountId, sessionToken);
      dishId = estimated.dishId("親子丼");
      await placeFreeTrialLastDay(accountId, addDays(today, -10));
      clock.advance(1000);
      await pushSyncWrites(sessionToken, {
        writes: [updateDishWrite(dishId, { name: "カツ丼" })],
      });
      await runEstimationAlarm(accountId);
    });

    test("料理ごとの推定の状態がサブスクリプションを待っているで届くこと", async () => {
      expect(await pullStatusesOf("dish_estimation_status")).toEqual([
        { dishId, status: "awaiting_subscription" },
      ]);
    });

    describe("そのあとテストユーザーの旗を立て、1時間たってから別の食事を送ったとき", () => {
      let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
      beforeEach(async () => {
        await markTestUser(accountId);
        await enableUsageEventSending(accountId);
        clock.advance(3_600_000);
        await recordPhotographedMeal(sessionToken);
        captureSpy = mockPostHogCaptureEndpointOk();
        await runEstimationAlarm(accountId);
      });

      test("推定し直しを終えた出来事の、受け取ってから終えるまでを、名前を直したときから数えること", () => {
        expect(
          readPostHogCapturedEvents(captureSpy)
            .filter(
              ({ event, properties }) =>
                event === "estimation_ended" && properties["trigger"] === "dish_renamed",
            )
            .map(({ properties }) => properties["seconds_from_received_to_ended"]),
        ).toEqual([3600]);
      });
    });
  });
});
