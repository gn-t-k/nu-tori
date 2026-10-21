import { beforeEach, describe, expect, test } from "vitest";
import type { SubscriptionStatusFacts } from "../subscription-status-store";
import { findSubscriptionCheck } from "./index";

type Facts = Parameters<typeof findSubscriptionCheck>[0];

// 無料体験の最後の日が 2026-11-02 になる、取引の無いアカウント
const freeTrialFacts: Facts = {
  startedOn: "2026-10-04",
  billingStartedOn: "2026-01-01",
  isExcludedByEarlierAccount: false,
  transactions: [],
};

const monthlyTransaction = (
  expiresAt: string,
): SubscriptionStatusFacts["transactions"][number] => ({
  appStoreProductId: "app.nu-tori.subscription.monthly",
  expiresAt: new Date(expiresAt),
  revocations: [],
  gracePeriodExpiresAts: [],
});

describe("課金の仕事が動く時刻", () => {
  describe("無料体験の最後の日が 2026-11-02 で、最新のタイムゾーンが東京のとき", () => {
    let timeZones: Parameters<typeof findSubscriptionCheck>[1];
    beforeEach(() => {
      timeZones = { latest: "Asia/Tokyo", firstSignIn: "America/New_York" };
    });

    test("あと3日の日の前なら、あと3日の日の東京の 0:00 に動くこと", () => {
      expect(
        findSubscriptionCheck(freeTrialFacts, timeZones, new Date("2026-10-30T00:00:00.000Z")),
      ).toEqual({ nextAt: new Date("2026-10-30T15:00:00.000Z"), isDue: false });
    });

    test("あと3日の日の 0:00 ちょうどなら、そこで動いたことにし、次は最後の日の 0:00 に動くこと", () => {
      expect(
        findSubscriptionCheck(freeTrialFacts, timeZones, new Date("2026-10-30T15:00:00.000Z")),
      ).toEqual({ nextAt: new Date("2026-11-01T15:00:00.000Z"), isDue: true });
    });

    test("最後の日のうちなら、最後の日の 0:00 から 24 時間の内なので動いたことにし、次は無料体験の終わり（次の日の 0:00）に動くこと", () => {
      expect(
        findSubscriptionCheck(freeTrialFacts, timeZones, new Date("2026-11-02T03:00:00.000Z")),
      ).toEqual({ nextAt: new Date("2026-11-02T15:00:00.000Z"), isDue: true });
    });

    test("無料体験の終わりから 24 時間を過ぎたら、もう動かないこと", () => {
      expect(
        findSubscriptionCheck(freeTrialFacts, timeZones, new Date("2026-11-03T15:00:00.001Z")),
      ).toEqual({ nextAt: undefined, isDue: false });
    });
  });

  describe("最新のタイムゾーンが読めず、最初のサインインのタイムゾーンがニューヨーク（2026-11-01 に夏時間が終わる）のとき", () => {
    let timeZones: Parameters<typeof findSubscriptionCheck>[1];
    beforeEach(() => {
      timeZones = { latest: undefined, firstSignIn: "America/New_York" };
    });

    test("あと3日の日の 0:00 を夏時間で出すこと", () => {
      expect(
        findSubscriptionCheck(freeTrialFacts, timeZones, new Date("2026-10-30T00:00:00.000Z")),
      ).toEqual({ nextAt: new Date("2026-10-31T04:00:00.000Z"), isDue: false });
    });

    test("最後の日の 0:00 を、夏時間が終わったあとの時差で出すこと", () => {
      expect(
        findSubscriptionCheck(freeTrialFacts, timeZones, new Date("2026-10-31T04:00:00.000Z")),
      ).toEqual({ nextAt: new Date("2026-11-02T05:00:00.000Z"), isDue: true });
    });
  });

  describe("どちらのタイムゾーンも無いとき", () => {
    let timeZones: Parameters<typeof findSubscriptionCheck>[1];
    beforeEach(() => {
      timeZones = { latest: undefined, firstSignIn: undefined };
    });

    test("UTC の 0:00 に動くこと", () => {
      expect(
        findSubscriptionCheck(freeTrialFacts, timeZones, new Date("2026-10-30T00:00:00.000Z")),
      ).toEqual({ nextAt: new Date("2026-10-31T00:00:00.000Z"), isDue: false });
    });
  });

  describe("無料体験が終わったあとに買い、サブスクリプションの終わりが 2026-12-10 12:00 のとき", () => {
    let facts: Facts;
    beforeEach(() => {
      facts = { ...freeTrialFacts, transactions: [monthlyTransaction("2026-12-10T12:00:00Z")] };
    });

    test("サブスクリプションの終わりに動くこと", () => {
      expect(
        findSubscriptionCheck(
          facts,
          { latest: "Asia/Tokyo", firstSignIn: undefined },
          new Date("2026-11-20T00:00:00.000Z"),
        ),
      ).toEqual({ nextAt: new Date("2026-12-10T12:00:00.000Z"), isDue: false });
    });
  });

  describe("作り直したアカウントで、取引が無いとき", () => {
    let facts: Facts;
    beforeEach(() => {
      facts = { ...freeTrialFacts, isExcludedByEarlierAccount: true };
    });

    test("動かないこと", () => {
      expect(
        findSubscriptionCheck(
          facts,
          { latest: "Asia/Tokyo", firstSignIn: undefined },
          new Date("2026-10-30T00:00:00.000Z"),
        ),
      ).toEqual({ nextAt: undefined, isDue: false });
    });
  });
});
