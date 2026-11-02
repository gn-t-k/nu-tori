import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { addDays } from "../../domain/add-days";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { generateRecordId } from "../../domain/record-id";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { signInTestAccount } from "../../http/testing";
import { markTestUser } from "./testing/mark-test-user";
import { placeFreeTrialLastDay } from "./testing/place-free-trial-last-day";
import { unmarkTestUser } from "./testing/unmark-test-user";

// 状態の変更を足す時機（#881）。取りに来た要求が、今の状態と最後に帳簿に載せた状態を比べ、違えば足す。
// 推定・返事・課金の仕事を通さず、事実を変えて取りに行くだけで確かめる
describe("サブスクリプションの状態の変更を足す時機", () => {
  let accountId: string;
  let pull: (afterSequence: number) => Promise<PullResult>;
  let pullStatusesAfter: (afterSequence: number) => Promise<Record<string, unknown>[]>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    const signedIn = await signInTestAccount(generateRecordId());
    accountId = signedIn.accountId;
    pull = async (afterSequence) =>
      (await pullSyncChanges(signedIn.sessionToken, { afterSequence })).json<PullResult>();
    pullStatusesAfter = async (afterSequence) =>
      (await pull(afterSequence)).changes
        .filter(({ kind }) => kind === "subscription_status")
        .map(({ record }) => record);
  });

  describe("最初のサインインのあと、初めて取りに行ったとき", () => {
    test("状態の変更が届くこと", async () => {
      expect(await pullStatusesAfter(0)).toEqual([expect.objectContaining({ type: "regular" })]);
    });
  });

  describe("一度取りに行き、事実が変わらないままもう一度取りに行ったとき", () => {
    let afterSequence: number;
    beforeEach(async () => {
      afterSequence = (await pull(0)).nextAfterSequence;
    });

    test("状態の変更は増えないこと", async () => {
      expect(await pullStatusesAfter(afterSequence)).toEqual([]);
    });
  });

  describe("一度取りに行ったあと、テストユーザーの旗を立てて取りに行ったとき", () => {
    let afterSequence: number;
    beforeEach(async () => {
      afterSequence = (await pull(0)).nextAfterSequence;
      await markTestUser(accountId);
    });

    test("テストユーザーの状態の変更が届くこと", async () => {
      expect(await pullStatusesAfter(afterSequence)).toEqual([{ type: "test_user" }]);
    });
  });

  // #876 の「設計について気づいたこと」の抜け。推定も文章も通さない
  describe("無料体験が終わったテストユーザーとして取りに行ったあと、旗を外して取りに行ったとき", () => {
    let afterSequence: number;
    beforeEach(async () => {
      const yesterday = addDays(computeCalendarDayInTimeZone(new Date(), "Asia/Tokyo"), -1);
      await placeFreeTrialLastDay(accountId, addDays(yesterday, -1));
      await markTestUser(accountId);
      afterSequence = (await pull(0)).nextAfterSequence;
      await unmarkTestUser(accountId);
    });

    test("サブスクリプションの無い状態の変更が届くこと", async () => {
      expect(await pullStatusesAfter(afterSequence)).toEqual([
        expect.objectContaining({ type: "regular", subscription: { type: "none" } }),
      ]);
    });
  });

  describe("課金を入れる前からのアカウント（帳簿に載せた状態が無い）が取りに行ったとき", () => {
    let afterSequence: number;
    beforeEach(async () => {
      afterSequence = (await pull(0)).nextAfterSequence;
      await runInDurableObject(getAccountDurableObject(env, accountId), (_, state) => {
        state.storage.sql.exec("DELETE FROM ledgered_subscription_statuses");
      });
    });

    test("状態の変更が届くこと", async () => {
      expect(await pullStatusesAfter(afterSequence)).toEqual([
        expect.objectContaining({ type: "regular" }),
      ]);
    });
  });
});
