import { runDurableObjectAlarm } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { enableUsageEventSending } from "../../http/sync-routes/testing/enable-usage-event-sending";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import { signInTestAccount } from "../../http/testing";
import { deleteMealWrite } from "../../meal/http/testing/delete-meal-write";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { mockCreateEstimationProviderOk } from "../durable-object/create-estimation-provider/create-estimation-provider.mock";
import { insertCountedEstimations } from "./testing/insert-counted-estimations";
import { readEarliestCountedOn } from "./testing/read-earliest-counted-on";
import { recordPhotographedMeal } from "./testing/record-photographed-meal";
import { runEstimationAlarm } from "./testing/run-estimation-alarm";
import { useFakeClock } from "./testing/use-fake-clock";
import { waitForEstimationAttempts } from "./testing/wait-for-estimation-attempts";

describe("推定の回数の上限", () => {
  let accountId: string;
  let sessionToken: string;
  let clock: ReturnType<typeof useFakeClock>;
  let pullChangesAfter: (afterSequence: number) => Promise<PullResult["changes"]>;
  let pullStatuses: (afterSequence?: number) => Promise<Record<string, unknown>[]>;
  let countEstimations: (countedOn: string) => Promise<number>;
  let readWaitingSchedules: () => Promise<Record<string, unknown>[]>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(crypto.randomUUID()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
    clock = useFakeClock(Date.now() + 86_400_000);
    pullChangesAfter = async (afterSequence) =>
      (await (await pullSyncChanges(sessionToken, { afterSequence })).json<PullResult>()).changes;
    pullStatuses = async (afterSequence = 0) =>
      (await pullChangesAfter(afterSequence))
        .filter(({ kind }) => kind === "meal_estimation_status")
        .map(({ record }) => record);
    countEstimations = async (countedOn) =>
      (
        await readRows(
          accountId,
          `SELECT estimations.id FROM estimations
           JOIN estimation_schedules ON estimation_schedules.id = estimations.estimation_schedule_id
           WHERE estimation_schedules.counted_on = '${countedOn}'`,
        )
      ).length;
    readWaitingSchedules = () =>
      readRows(
        accountId,
        `SELECT counted_on, due_at FROM estimation_schedules
         WHERE id NOT IN (SELECT estimation_schedule_id FROM estimations)
           AND id NOT IN (SELECT estimation_schedule_id FROM estimation_deferrals)`,
      );
  });

  describe("その日の推定が 29 回で、同じ日の予定が3つ待っているとき", () => {
    let countedOn: string;
    let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      mockCreateEstimationProviderOk();
      await recordPhotographedMeal(sessionToken);
      await recordPhotographedMeal(sessionToken);
      await recordPhotographedMeal(sessionToken);
      countedOn = await readEarliestCountedOn(accountId);
      await insertCountedEstimations(accountId, countedOn, 29);
      captureSpy = mockPostHogCaptureEndpointOk();
      await runEstimationAlarm(accountId);
    });

    test("その日の推定を 30 回で止めること", async () => {
      expect(await countEstimations(countedOn)).toBe(30);
    });

    test("始めた食事は推定できたに、始められなかった食事は翌日に推定にすること", async () => {
      expect(
        (await pullStatuses())
          .map(({ status }) => String(status))
          .toSorted((a, b) => a.localeCompare(b)),
      ).toEqual(["deferred_to_next_day", "deferred_to_next_day", "estimated"]);
    });

    test("見送った予定ごとに、次の日の 0:00 過ぎの予定を、次の日の分として足すこと", async () => {
      expect(await readWaitingSchedules()).toEqual([
        { counted_on: nextDayOf(countedOn), due_at: startOfDay(nextDayOf(countedOn)) },
        { counted_on: nextDayOf(countedOn), due_at: startOfDay(nextDayOf(countedOn)) },
      ]);
    });

    test("推定を翌日に回した出来事を、見送った数だけ送ること", () => {
      expect(
        readPostHogCapturedEvents(captureSpy).filter(
          ({ event }) => event === "estimation_deferred",
        ),
      ).toEqual([
        {
          event: "estimation_deferred",
          distinct_id: accountId,
          properties: { $geoip_disable: true },
        },
        {
          event: "estimation_deferred",
          distinct_id: accountId,
          properties: { $geoip_disable: true },
        },
      ]);
    });
  });

  describe("見送られた食事の、次の日の 0:00 を過ぎたとき", () => {
    let mealId: string;
    let countedOn: string;
    let advanceToNextDay: () => void;
    beforeEach(async () => {
      mockCreateEstimationProviderOk();
      mealId = await recordPhotographedMeal(sessionToken);
      countedOn = await readEarliestCountedOn(accountId);
      await insertCountedEstimations(accountId, countedOn, 30);
      await runEstimationAlarm(accountId);
      advanceToNextDay = () => {
        clock.advance(startOfDay(nextDayOf(countedOn)) - Date.now() + 60_000);
      };
    });

    describe("次の日の推定が 30 回に満たないとき", () => {
      let sequenceBeforeStart: number;
      beforeEach(async () => {
        mockCreateEstimationProviderOk({ replyAfter: new Promise(() => undefined) });
        sequenceBeforeStart = (await (await pullSyncChanges(sessionToken)).json<PullResult>())
          .nextAfterSequence;
        advanceToNextDay();
        // 止まったアラームは終わらないので待たない
        void runDurableObjectAlarm(getAccountDurableObject(env, accountId));
        await waitForEstimationAttempts(accountId, 1);
      });

      test("推定中に戻し、その推定の状態の変更を足すこと", async () => {
        expect(await pullStatuses(sequenceBeforeStart)).toEqual([{ mealId, status: "estimating" }]);
      });

      test("次の日の分に数えること", async () => {
        expect({
          countedDay: await countEstimations(countedOn),
          nextDay: await countEstimations(nextDayOf(countedOn)),
        }).toEqual({ countedDay: 30, nextDay: 1 });
      });
    });

    describe("次の日の推定も 30 回に達しているとき", () => {
      beforeEach(async () => {
        await insertCountedEstimations(accountId, nextDayOf(countedOn), 30);
        advanceToNextDay();
        await runEstimationAlarm(accountId);
      });

      test("また見送り、翌日に推定のままにすること", async () => {
        expect(await pullStatuses()).toEqual([{ mealId, status: "deferred_to_next_day" }]);
      });

      test("その次の日の 0:00 過ぎの予定を、その次の日の分として足すこと", async () => {
        expect(await readWaitingSchedules()).toEqual([
          {
            counted_on: nextDayOf(nextDayOf(countedOn)),
            due_at: startOfDay(nextDayOf(nextDayOf(countedOn))),
          },
        ]);
      });
    });
  });

  describe("推定を始めた食事を消したあとで、同じ日の予定が待っているとき", () => {
    let mealId: string;
    beforeEach(async () => {
      mockCreateEstimationProviderOk();
      const startedMealId = await recordPhotographedMeal(sessionToken);
      await insertCountedEstimations(accountId, await readEarliestCountedOn(accountId), 29);
      await runEstimationAlarm(accountId);
      await pushSyncWrites(sessionToken, { writes: [deleteMealWrite(startedMealId)] });
      mealId = await recordPhotographedMeal(sessionToken);
      await runEstimationAlarm(accountId);
    });

    test("消した分の回数を戻さず、見送ること", async () => {
      expect(await pullStatuses()).toEqual([{ mealId, status: "deferred_to_next_day" }]);
    });
  });
});

// テストの同期の要求のタイムゾーンはアジア/東京なので、日の区切りは東京の 0:00
const nextDayOf = (day: string) =>
  new Date(Date.parse(`${day}T00:00:00Z`) + 86_400_000).toISOString().slice(0, 10);

const startOfDay = (day: string) => Date.parse(`${day}T00:00:00+09:00`);
