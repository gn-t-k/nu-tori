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
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { signInTestAccount } from "../../http/testing";
import { createWeightRecordWrite } from "../../weight-record/http/testing/create-weight-record-write";
import { markTestUser } from "./testing/mark-test-user";
import { placeFreeTrialLastDay } from "./testing/place-free-trial-last-day";

// 課金の仕事（アラーム）が動く時刻。状態の変更は足さない（取りに来たときに足す。#881）。同期の要求は Asia/Tokyo で送る
describe("課金の仕事のアラーム", () => {
  let accountId: string;
  let sessionToken: string;
  let today: string;
  let readAlarm: () => Promise<number | null>;
  let countStatusChanges: () => Promise<number>;
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
    // 取りに行くと状態の変更を足しうるので、帳簿を直に数える
    countStatusChanges = () =>
      runInDurableObject(
        getAccountDurableObject(env, accountId),
        (_, state) =>
          state.storage.sql
            .exec("SELECT sequence FROM record_changes WHERE record_type = 'subscription_status'")
            .toArray().length,
      );
  });

  describe("無料体験の最後の日が3日後のアカウントに、送る要求が届いたとき", () => {
    let lastDay: string;
    beforeEach(async () => {
      lastDay = addDays(today, 3);
      await placeFreeTrialLastDay(accountId, lastDay);
      await pushSyncWrites(sessionToken, { writes: [createWeightRecordWrite()] });
    });

    test("無料体験の終わり（最後の日の次の日の東京の 0:00）にアラームを張ること", async () => {
      expect(await readAlarm()).toBe(Date.parse(`${addDays(lastDay, 1)}T00:00:00+09:00`));
    });

    describe("テストユーザーの旗を立て、無料体験の終わりにアラームが動いたとき", () => {
      let countBeforeAlarm: number;
      beforeEach(async () => {
        countBeforeAlarm = await countStatusChanges();
        await markTestUser(accountId);
        vi.setSystemTime(Date.parse(`${addDays(lastDay, 1)}T00:00:00+09:00`));
        await runDurableObjectAlarm(getAccountDurableObject(env, accountId));
      });

      test("状態の変更を足さないこと", async () => {
        expect(await countStatusChanges()).toBe(countBeforeAlarm);
      });

      test("次に動く時刻が無ければ、アラームを外すこと", async () => {
        expect(await readAlarm()).toBeNull();
      });
    });
  });
});
