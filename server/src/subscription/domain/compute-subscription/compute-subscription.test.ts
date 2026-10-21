import { beforeEach, describe, expect, test } from "vitest";
import type { SubscriptionTransactionFact } from "../subscription";
import { computeSubscription } from "./index";

const monthly = "app.nu-tori.subscription.monthly";
const yearly = "app.nu-tori.subscription.yearly";

const transaction = (
  fact: Pick<SubscriptionTransactionFact, "appStoreProductId" | "expiresAt"> &
    Partial<SubscriptionTransactionFact>,
): SubscriptionTransactionFact => ({
  environment: "production",
  revocations: [],
  gracePeriodExpiresAts: [],
  ...fact,
});

describe("サブスクリプション", () => {
  describe("取引が無いとき", () => {
    let transactions: SubscriptionTransactionFact[];
    beforeEach(() => {
      transactions = [];
    });

    test("サブスクリプションが無いこと", () => {
      expect(computeSubscription(transactions)).toEqual({ type: "none" });
    });
  });

  describe("月額を買って1度更新したとき", () => {
    let transactions: SubscriptionTransactionFact[];
    beforeEach(() => {
      transactions = [
        transaction({ appStoreProductId: monthly, expiresAt: new Date("2026-12-01T00:00:00Z") }),
        transaction({ appStoreProductId: monthly, expiresAt: new Date("2026-11-01T00:00:00Z") }),
      ];
    });

    test("並びの順によらず、期限がいちばん遅い取引の月額と期限を持ち、猶予を持たないこと", () => {
      expect(computeSubscription(transactions)).toEqual({
        type: "subscribed",
        plan: "monthly",
        periodEndsAt: new Date("2026-12-01T00:00:00Z"),
        billingGrace: { type: "none" },
      });
    });
  });

  describe("月額のあとに年額に変えたとき", () => {
    let transactions: SubscriptionTransactionFact[];
    beforeEach(() => {
      transactions = [
        transaction({ appStoreProductId: monthly, expiresAt: new Date("2026-11-01T00:00:00Z") }),
        transaction({ appStoreProductId: yearly, expiresAt: new Date("2027-11-01T00:00:00Z") }),
      ];
    });

    test("年額と、その期限を持つこと", () => {
      expect(computeSubscription(transactions)).toMatchObject({
        type: "subscribed",
        plan: "yearly",
        periodEndsAt: new Date("2027-11-01T00:00:00Z"),
      });
    });
  });

  describe("請求の猶予の終わりが期限より遅いとき", () => {
    let transactions: SubscriptionTransactionFact[];
    beforeEach(() => {
      transactions = [
        transaction({
          appStoreProductId: monthly,
          expiresAt: new Date("2026-11-01T00:00:00Z"),
          gracePeriodExpiresAts: [
            new Date("2026-11-10T00:00:00Z"),
            new Date("2026-11-17T00:00:00Z"),
          ],
        }),
      ];
    });

    test("猶予の終わりの最大を持つこと", () => {
      expect(computeSubscription(transactions)).toEqual({
        type: "subscribed",
        plan: "monthly",
        periodEndsAt: new Date("2026-11-01T00:00:00Z"),
        billingGrace: { type: "granted", endsAt: new Date("2026-11-17T00:00:00Z") },
      });
    });
  });

  describe("猶予のあとに請求を取り戻して更新し、猶予の終わりが新しい期限より前のとき", () => {
    let transactions: SubscriptionTransactionFact[];
    beforeEach(() => {
      transactions = [
        transaction({
          appStoreProductId: monthly,
          expiresAt: new Date("2026-11-01T00:00:00Z"),
          gracePeriodExpiresAts: [new Date("2026-11-17T00:00:00Z")],
        }),
        transaction({ appStoreProductId: monthly, expiresAt: new Date("2026-12-05T00:00:00Z") }),
      ];
    });

    test("猶予を持たないこと", () => {
      expect(computeSubscription(transactions)).toMatchObject({
        periodEndsAt: new Date("2026-12-05T00:00:00Z"),
        billingGrace: { type: "none" },
      });
    });
  });

  describe("期限がいちばん遅い取引が取り消されたとき", () => {
    let transactions: SubscriptionTransactionFact[];
    beforeEach(() => {
      transactions = [
        transaction({ appStoreProductId: monthly, expiresAt: new Date("2026-11-01T00:00:00Z") }),
        transaction({
          appStoreProductId: yearly,
          expiresAt: new Date("2027-11-01T00:00:00Z"),
          revocations: [{ reversed: false }],
        }),
      ];
    });

    test("取り消した取引を外して、残りの取引の商品と期限を持つこと", () => {
      expect(computeSubscription(transactions)).toMatchObject({
        plan: "monthly",
        periodEndsAt: new Date("2026-11-01T00:00:00Z"),
      });
    });
  });

  describe("取り消された取引の猶予の終わりが、残りの取引の期限より遅いとき", () => {
    let transactions: SubscriptionTransactionFact[];
    beforeEach(() => {
      transactions = [
        transaction({ appStoreProductId: monthly, expiresAt: new Date("2026-11-01T00:00:00Z") }),
        transaction({
          appStoreProductId: monthly,
          expiresAt: new Date("2026-10-01T00:00:00Z"),
          gracePeriodExpiresAts: [new Date("2026-11-20T00:00:00Z")],
          revocations: [{ reversed: false }],
        }),
      ];
    });

    test("取り消された取引の猶予を数えないこと", () => {
      expect(computeSubscription(transactions)).toMatchObject({ billingGrace: { type: "none" } });
    });
  });

  describe("取り消しが戻された取引があるとき", () => {
    let transactions: SubscriptionTransactionFact[];
    beforeEach(() => {
      transactions = [
        transaction({
          appStoreProductId: monthly,
          expiresAt: new Date("2026-11-01T00:00:00Z"),
          revocations: [{ reversed: true }],
        }),
      ];
    });

    test("その取引を外さないこと", () => {
      expect(computeSubscription(transactions)).toMatchObject({
        type: "subscribed",
        periodEndsAt: new Date("2026-11-01T00:00:00Z"),
      });
    });
  });

  describe("取り消しが戻されたあと、また取り消された取引だけがあるとき", () => {
    let transactions: SubscriptionTransactionFact[];
    beforeEach(() => {
      transactions = [
        transaction({
          appStoreProductId: monthly,
          expiresAt: new Date("2026-11-01T00:00:00Z"),
          revocations: [{ reversed: true }, { reversed: false }],
        }),
      ];
    });

    test("サブスクリプションが無いこと", () => {
      expect(computeSubscription(transactions)).toEqual({ type: "none" });
    });
  });
});
