import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { signInTestAccount } from "../../http/testing";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { createMealWrite } from "../../meal/http/testing/create-meal-write";
import { insertEstimationSchedule } from "./testing/insert-estimation-schedule";
import { beforeEach, describe, expect, test } from "vitest";

describe("推定の状態の同期", () => {
  let accountId: string;
  let sessionToken: string;
  let mealId: string;
  let pullStatus: () => Promise<unknown>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(crypto.randomUUID()));
    mealId = crypto.randomUUID();
    await pushSyncWrites(sessionToken, { writes: [createMealWrite({ meal: { id: mealId } })] });
    pullStatus = async () => {
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
      return pulled.changes.find(({ kind }) => kind === "meal_estimation_status")?.record;
    };
  });

  describe("食事に推定の予定が無いとき", () => {
    test("写真を待っていること", async () => {
      expect(await pullStatus()).toEqual({ mealId, status: "awaiting_photos" });
    });
  });

  describe("予定があり、まだ推定を始めていないとき", () => {
    beforeEach(async () => {
      await insertEstimationSchedule(accountId, mealId, {
        dueAt: Date.UTC(2026, 9, 1),
        progress: "waiting",
      });
    });

    test("推定中であること", async () => {
      expect(await pullStatus()).toEqual({ mealId, status: "estimating" });
    });
  });

  describe("推定を始め、完了も断念もしていないとき", () => {
    beforeEach(async () => {
      await insertEstimationSchedule(accountId, mealId, {
        dueAt: Date.UTC(2026, 9, 1),
        progress: "started",
      });
    });

    test("推定中であること", async () => {
      expect(await pullStatus()).toEqual({ mealId, status: "estimating" });
    });
  });

  describe("推定が料理ありで完了したとき", () => {
    beforeEach(async () => {
      await insertEstimationSchedule(accountId, mealId, {
        dueAt: Date.UTC(2026, 9, 1),
        progress: "estimated",
      });
    });

    test("推定できたこと", async () => {
      expect(await pullStatus()).toEqual({ mealId, status: "estimated" });
    });
  });

  describe("推定が料理なしで完了したとき", () => {
    beforeEach(async () => {
      await insertEstimationSchedule(accountId, mealId, {
        dueAt: Date.UTC(2026, 9, 1),
        progress: "no_dishes",
      });
    });

    test("料理なしであること", async () => {
      expect(await pullStatus()).toEqual({ mealId, status: "no_dishes" });
    });
  });

  describe("推定を諦めたとき", () => {
    beforeEach(async () => {
      await insertEstimationSchedule(accountId, mealId, {
        dueAt: Date.UTC(2026, 9, 1),
        progress: "abandoned",
      });
    });

    test("推定できなかったこと", async () => {
      expect(await pullStatus()).toEqual({ mealId, status: "failed" });
    });
  });

  describe("回数切れで見送り、次の日の予定をまだ始めていないとき", () => {
    beforeEach(async () => {
      await insertEstimationSchedule(accountId, mealId, {
        dueAt: Date.UTC(2026, 9, 1, 3),
        progress: "deferred",
      });
      await insertEstimationSchedule(accountId, mealId, {
        dueAt: Date.UTC(2026, 9, 1, 15, 0, 1),
        progress: "waiting",
      });
    });

    test("翌日に推定であること", async () => {
      expect(await pullStatus()).toEqual({ mealId, status: "deferred_to_next_day" });
    });
  });

  describe("見送ったあと、次の日の予定から推定を始めたとき", () => {
    beforeEach(async () => {
      await insertEstimationSchedule(accountId, mealId, {
        dueAt: Date.UTC(2026, 9, 1, 3),
        progress: "deferred",
      });
      await insertEstimationSchedule(accountId, mealId, {
        dueAt: Date.UTC(2026, 9, 1, 15, 0, 1),
        progress: "started",
      });
    });

    test("推定中であること", async () => {
      expect(await pullStatus()).toEqual({ mealId, status: "estimating" });
    });
  });

  describe("見送ったあと、次の日の予定で推定できたとき", () => {
    beforeEach(async () => {
      await insertEstimationSchedule(accountId, mealId, {
        dueAt: Date.UTC(2026, 9, 1, 3),
        progress: "deferred",
      });
      await insertEstimationSchedule(accountId, mealId, {
        dueAt: Date.UTC(2026, 9, 1, 15, 0, 1),
        progress: "estimated",
      });
    });

    test("推定できたこと", async () => {
      expect(await pullStatus()).toEqual({ mealId, status: "estimated" });
    });
  });
});
