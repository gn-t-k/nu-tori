import { beforeEach, describe, expect, test } from "vitest";
import type { Subscription } from "../compute-subscription";
import { computeSubscriptionEnd } from "./index";

describe("サブスクリプションの終わり", () => {
  describe("サブスクリプションが無いとき", () => {
    let subscription: Subscription;
    beforeEach(() => {
      subscription = { type: "none" };
    });

    test("終わりが無いこと", () => {
      expect(computeSubscriptionEnd(subscription)).toBeUndefined();
    });
  });

  describe("猶予の無いサブスクリプションのとき", () => {
    let subscription: Subscription;
    beforeEach(() => {
      subscription = {
        type: "subscribed",
        plan: "monthly",
        periodEndsAt: new Date("2026-12-01T00:00:00Z"),
        billingGrace: { type: "none" },
      };
    });

    test("期限が終わりであること", () => {
      expect(computeSubscriptionEnd(subscription)).toEqual(new Date("2026-12-01T00:00:00Z"));
    });
  });

  describe("期限より遅い猶予の終わりがあるとき", () => {
    let subscription: Subscription;
    beforeEach(() => {
      subscription = {
        type: "subscribed",
        plan: "monthly",
        periodEndsAt: new Date("2026-12-01T00:00:00Z"),
        billingGrace: { type: "granted", endsAt: new Date("2026-12-17T00:00:00Z") },
      };
    });

    test("猶予の終わりが終わりであること", () => {
      expect(computeSubscriptionEnd(subscription)).toEqual(new Date("2026-12-17T00:00:00Z"));
    });
  });
});
