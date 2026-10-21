import { runDurableObjectAlarm, runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test, vi } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { addDays } from "../../domain/add-days";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { generateRecordId } from "../../domain/record-id";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { requireLastSequence } from "../../http/sync-routes/testing/require-last-sequence";
import { signInTestAccount } from "../../http/testing";
import { createWeightRecordWrite } from "../../weight-record/http/testing/create-weight-record-write";
import { markTestUser } from "./testing/mark-test-user";
import { placeFreeTrialLastDay } from "./testing/place-free-trial-last-day";

// 課金の仕事（アラーム）が状態の記録の変更を足す時機（#647 の「同期」の「変更を足す時機」の 2）。同期の要求は Asia/Tokyo で送る
describe("課金の仕事のアラーム", () => {
  let accountId: string;
  let sessionToken: string;
  let today: string;
  let readAlarm: () => Promise<number | null>;
  let pullStatusChangesAfter: (afterSequence: number) => Promise<Record<string, unknown>[]>;
  let readLastSequence: () => Promise<number>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
    useFakeClock(Date.now() + 86_400_000);
    today = computeCalendarDayInTimeZone(new Date(), "Asia/Tokyo");
    readAlarm = () =>
      runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
        state.storage.getAlarm(),
      );
    pullStatusChangesAfter = async (afterSequence) =>
      (await (await pullSyncChanges(sessionToken, { afterSequence })).json<PullResult>()).changes
        .filter(({ kind }) => kind === "subscription_status")
        .map(({ record }) => record);
    readLastSequence = async () =>
      requireLastSequence((await (await pullSyncChanges(sessionToken)).json<PullResult>()).changes);
  });

  describe("無料体験の最後の日が3日後のアカウントに、送る要求が届いたとき", () => {
    let lastDay: string;
    beforeEach(async () => {
      lastDay = addDays(today, 3);
      await placeFreeTrialLastDay(accountId, lastDay);
      await pushSyncWrites(sessionToken, { writes: [createWeightRecordWrite()] });
    });

    test("あと3日の日の東京の 0:00 にアラームを張ること", async () => {
      expect(await readAlarm()).toBe(Date.parse(`${addDays(lastDay, -2)}T00:00:00+09:00`));
    });

    describe("テストユーザーの旗を立て、あと3日の日の 0:00 にアラームが動いたとき", () => {
      let sequenceBeforeAlarm: number;
      beforeEach(async () => {
        sequenceBeforeAlarm = await readLastSequence();
        await markTestUser(accountId);
        vi.setSystemTime(Date.parse(`${addDays(lastDay, -2)}T00:00:00+09:00`));
        await runDurableObjectAlarm(getAccountDurableObject(env, accountId));
      });

      test("テストユーザーの状態の変更が届くこと", async () => {
        expect(await pullStatusChangesAfter(sequenceBeforeAlarm)).toEqual([{ type: "test_user" }]);
      });

      test("次は最後の日の 0:00 にアラームを張ること", async () => {
        expect(await readAlarm()).toBe(Date.parse(`${lastDay}T00:00:00+09:00`));
      });
    });
  });

  describe("課金を入れる前からのアカウント（状態の記録の変更が帳簿に無い）に、送る要求が届いたとき", () => {
    let sequenceBeforeAlarm: number;
    beforeEach(async () => {
      await runInDurableObject(getAccountDurableObject(env, accountId), (_, state) => {
        state.storage.sql.exec(
          "DELETE FROM record_changes WHERE record_type = 'subscription_status'",
        );
      });
      await pushSyncWrites(sessionToken, { writes: [createWeightRecordWrite()] });
      sequenceBeforeAlarm = await readLastSequence();
    });

    test("今すぐアラームを張ること", async () => {
      expect(await readAlarm()).toBe(Date.now());
    });

    describe("アラームが動いたとき", () => {
      beforeEach(async () => {
        await runDurableObjectAlarm(getAccountDurableObject(env, accountId));
      });

      test("状態の変更が届くこと", async () => {
        expect(await pullStatusChangesAfter(sequenceBeforeAlarm)).toEqual([
          expect.objectContaining({ type: "regular" }),
        ]);
      });

      test("次は課金の区切りの時刻にアラームを張ること", async () => {
        expect(await readAlarm()).toBeGreaterThan(Date.now());
      });
    });
  });
});
