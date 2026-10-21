import { beforeEach, describe, expect, test } from "vitest";
import type { SubscriptionStatus } from "../subscription-status";
import { isSubscriptionExpired } from "./index";

describe("サブスクリプション切れか", () => {
  describe("テストユーザーのとき", () => {
    let status: SubscriptionStatus;
    beforeEach(() => {
      status = { type: "test_user" };
    });

    test("無料体験もサブスクリプションも無くても、切れでないこと", () => {
      expect(
        isSubscriptionExpired(status, {
          countedOn: "2027-01-01",
          now: new Date("2027-01-01T00:00:00.000Z"),
        }),
      ).toBe(false);
    });
  });

  describe("最後の日が 2026-11-30 の無料体験があり、サブスクリプションが無いとき", () => {
    let status: SubscriptionStatus;
    beforeEach(() => {
      status = {
        type: "regular",
        freeTrial: { type: "available", lastDay: "2026-11-30" },
        subscription: { type: "none" },
      };
    });

    test("数える日が最後の日なら、今が次の日でも切れでないこと", () => {
      expect(
        isSubscriptionExpired(status, {
          countedOn: "2026-11-30",
          now: new Date("2026-12-01T03:00:00.000Z"),
        }),
      ).toBe(false);
    });

    test("数える日が最後の日の次の日なら、切れであること", () => {
      expect(
        isSubscriptionExpired(status, {
          countedOn: "2026-12-01",
          now: new Date("2026-12-01T03:00:00.000Z"),
        }),
      ).toBe(true);
    });
  });

  describe("作り直したアカウントで、猶予のあるサブスクリプションがあるとき", () => {
    let status: SubscriptionStatus;
    beforeEach(() => {
      status = {
        type: "regular",
        freeTrial: { type: "used_by_earlier_account" },
        subscription: {
          type: "subscribed",
          plan: "monthly",
          periodEndsAt: new Date("2026-12-01T00:00:00.000Z"),
          billingGrace: { type: "granted", endsAt: new Date("2026-12-17T00:00:00.000Z") },
        },
      };
    });

    test("今が猶予の終わりより前なら、切れでないこと", () => {
      expect(
        isSubscriptionExpired(status, {
          countedOn: "2026-12-16",
          now: new Date("2026-12-16T23:59:59.999Z"),
        }),
      ).toBe(false);
    });

    test("今が猶予の終わりちょうどなら、切れであること", () => {
      expect(
        isSubscriptionExpired(status, {
          countedOn: "2026-12-17",
          now: new Date("2026-12-17T00:00:00.000Z"),
        }),
      ).toBe(true);
    });
  });
});
