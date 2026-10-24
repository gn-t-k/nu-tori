import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { drizzle as drizzleD1 } from "drizzle-orm/d1";
import { beforeEach, describe, expect, test } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { generateRecordId, type RecordId, recordIdSchema } from "../../domain/record-id";
import { createRecordChangeWriter } from "../../durable-object/create-record-change-writer";
import { durableObjectTables } from "../../durable-object/durable-object-tables";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { durableObjectFactory } from "../../durable-object/testing/durable-object-factory";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { signInTestAccount } from "../../http/testing";
import { subscriptionD1Tables } from "../../subscription/d1/subscription-d1-tables";

type Factory = ReturnType<typeof durableObjectFactory>;

// 課金を入れた日は、テストでは vitest.config.ts の値（2026-01-01）。
// まだ取引を書く口が無いので、表に行を置き、記録の変化を書く入口で状態の記録の変更を足す
describe("サブスクリプションの状態の同期", () => {
  let accountId: string;
  let firstSignInId: RecordId;
  let seed: (rows: (factory: Factory) => Promise<void>) => Promise<void>;
  let pullStatus: () => Promise<Omit<PullResult["changes"][number], "sequence"> | undefined>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    const signedIn = await signInTestAccount(generateRecordId());
    accountId = signedIn.accountId;
    const account = getAccountDurableObject(env, accountId);
    // サインインした日によらない最後の日にするため、アカウントを作った日を置き直す
    firstSignInId = await runInDurableObject(account, (_, state) => {
      const [row] = state.storage.sql
        .exec<{ id: string }>("UPDATE first_sign_ins SET started_on = '2026-09-01' RETURNING id")
        .toArray();
      if (row === undefined) {
        throw new Error("最初のサインインが無い");
      }
      return recordIdSchema.parse(row.id);
    });
    seed = (rows) =>
      runInDurableObject(account, async (_, state) => {
        await rows(durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables })));
        createRecordChangeWriter(state.storage)(({ addChange }) => {
          addChange({ recordType: "subscription_status", recordId: firstSignInId });
        });
      });
    pullStatus = async () => {
      const { changes } = await (await pullSyncChanges(signedIn.sessionToken)).json<PullResult>();
      const change = changes.findLast(({ kind }) => kind === "subscription_status");
      return change === undefined
        ? undefined
        : { kind: change.kind, recordId: change.recordId, record: change.record };
    };
  });

  describe("最初のサインインのあと、取引が無いとき", () => {
    test("最初のサインインの ID で、無料体験の最後の日を持ち、サブスクリプションの無い状態が届くこと", async () => {
      expect(await pullStatus()).toEqual({
        kind: "subscription_status",
        recordId: firstSignInId,
        record: {
          type: "regular",
          freeTrial: { type: "available", lastDay: "2026-09-30" },
          subscription: { type: "none" },
        },
      });
    });
  });

  describe("課金を入れた日より前にアカウントを作ったとき", () => {
    beforeEach(async () => {
      await seed(async () => {});
      await runInDurableObject(getAccountDurableObject(env, accountId), (_, state) => {
        state.storage.sql.exec("UPDATE first_sign_ins SET started_on = '2025-12-10'");
      });
    });

    test("課金を入れた日から数えた最後の日が届くこと", async () => {
      expect((await pullStatus())?.record).toMatchObject({
        freeTrial: { type: "available", lastDay: "2026-01-30" },
      });
    });
  });

  describe("月額の取引が2つあるとき", () => {
    beforeEach(async () => {
      await seed(async (factory) => {
        const { subscriptionId } = await factory.appStoreSubscriptions.create();
        await createTransaction(factory, {
          subscriptionId,
          appStoreProductId: "app.nu_tori.subscription.monthly",
          expiresAt: new Date("2026-10-15T00:00:00Z"),
        });
        await createTransaction(factory, {
          subscriptionId,
          appStoreProductId: "app.nu_tori.subscription.monthly",
          expiresAt: new Date("2026-11-15T00:00:00Z"),
        });
      });
    });

    test("月額と、いちばん遅い期限を持ち、猶予の無いサブスクリプションが届くこと", async () => {
      expect((await pullStatus())?.record).toEqual({
        type: "regular",
        freeTrial: { type: "available", lastDay: "2026-09-30" },
        subscription: {
          type: "subscribed",
          plan: "monthly",
          periodEndsAt: "2026-11-15T00:00:00.000Z",
          billingGrace: { type: "none" },
        },
      });
    });
  });

  describe("年額の取引に、期限より遅い請求の猶予がついたとき", () => {
    beforeEach(async () => {
      await seed(async (factory) => {
        const { id } = await createTransaction(factory, {
          appStoreProductId: "app.nu_tori.subscription.yearly",
          expiresAt: new Date("2026-11-15T00:00:00Z"),
        });
        const failure = await factory.subscriptionBillingFailures.create({
          subscriptionTransactionId: id,
        });
        await factory.subscriptionGracePeriods.create({
          subscriptionBillingFailureId: failure.id,
          gracePeriodExpiresAt: new Date("2026-12-01T00:00:00Z"),
        });
      });
    });

    test("猶予の終わりを持つサブスクリプションが届くこと", async () => {
      expect((await pullStatus())?.record).toMatchObject({
        subscription: {
          type: "subscribed",
          plan: "yearly",
          periodEndsAt: "2026-11-15T00:00:00.000Z",
          billingGrace: { type: "granted", endsAt: "2026-12-01T00:00:00.000Z" },
        },
      });
    });
  });

  describe("請求の猶予のあとに更新し、猶予の終わりが新しい期限より前のとき", () => {
    beforeEach(async () => {
      await seed(async (factory) => {
        const { subscriptionId } = await factory.appStoreSubscriptions.create();
        const { id } = await createTransaction(factory, {
          subscriptionId,
          appStoreProductId: "app.nu_tori.subscription.monthly",
          expiresAt: new Date("2026-10-15T00:00:00Z"),
        });
        const failure = await factory.subscriptionBillingFailures.create({
          subscriptionTransactionId: id,
        });
        await factory.subscriptionGracePeriods.create({
          subscriptionBillingFailureId: failure.id,
          gracePeriodExpiresAt: new Date("2026-10-31T00:00:00Z"),
        });
        await createTransaction(factory, {
          subscriptionId,
          appStoreProductId: "app.nu_tori.subscription.monthly",
          expiresAt: new Date("2026-11-20T00:00:00Z"),
        });
      });
    });

    test("猶予の無いサブスクリプションが届くこと", async () => {
      expect((await pullStatus())?.record).toMatchObject({
        subscription: {
          periodEndsAt: "2026-11-20T00:00:00.000Z",
          billingGrace: { type: "none" },
        },
      });
    });
  });

  describe("取引がすべて取り消されたとき", () => {
    beforeEach(async () => {
      await seed(async (factory) => {
        const { subscriptionId } = await factory.appStoreSubscriptions.create();
        for (const expiresAt of ["2026-10-15T00:00:00Z", "2026-11-15T00:00:00Z"]) {
          const { id } = await createTransaction(factory, {
            subscriptionId,
            appStoreProductId: "app.nu_tori.subscription.monthly",
            expiresAt: new Date(expiresAt),
          });
          await factory.subscriptionTransactionRevocations.create({
            subscriptionTransactionId: id,
          });
        }
      });
    });

    test("サブスクリプションの無い状態が届くこと", async () => {
      expect((await pullStatus())?.record).toMatchObject({ subscription: { type: "none" } });
    });
  });

  describe("取り消しが戻されたとき", () => {
    beforeEach(async () => {
      await seed(async (factory) => {
        const { id } = await createTransaction(factory, {
          appStoreProductId: "app.nu_tori.subscription.monthly",
          expiresAt: new Date("2026-11-15T00:00:00Z"),
        });
        const revocation = await factory.subscriptionTransactionRevocations.create({
          subscriptionTransactionId: id,
        });
        await factory.subscriptionTransactionRevocationReversals.create({
          subscriptionTransactionRevocationId: revocation.id,
        });
      });
    });

    test("その取引のサブスクリプションが届くこと", async () => {
      expect((await pullStatus())?.record).toMatchObject({
        subscription: { type: "subscribed", periodEndsAt: "2026-11-15T00:00:00.000Z" },
      });
    });
  });

  describe("作り直したアカウントのとき", () => {
    beforeEach(async () => {
      await seed(async (factory) => {
        await factory.freeTrialExclusions.create({ firstSignInId });
      });
    });

    test("無料体験を前のアカウントで使った状態が届くこと", async () => {
      expect((await pullStatus())?.record).toEqual({
        type: "regular",
        freeTrial: { type: "used_by_earlier_account" },
        subscription: { type: "none" },
      });
    });
  });

  describe("テストユーザーのとき", () => {
    beforeEach(async () => {
      await drizzleD1(env.DB).insert(subscriptionD1Tables.testUsers).values({ accountId });
      await seed(async (factory) => {
        await createTransaction(factory, {
          appStoreProductId: "app.nu_tori.subscription.monthly",
          expiresAt: new Date("2026-11-15T00:00:00Z"),
        });
      });
    });

    test("ほかの値を持たないテストユーザーの状態が届くこと", async () => {
      expect((await pullStatus())?.record).toEqual({ type: "test_user" });
    });
  });
});

// App Store の取引を、それを書いた受け取りと一緒に作る。サブスクリプションを渡さなければ新しく作る
const createTransaction = async (
  factory: Factory,
  transaction: {
    subscriptionId?: RecordId;
    appStoreProductId: string;
    expiresAt: Date;
  },
) => {
  const created = await factory.subscriptionTransactions.create({
    expiresAt: transaction.expiresAt,
    ...(transaction.subscriptionId === undefined
      ? {}
      : { subscriptionId: transaction.subscriptionId }),
  });
  await factory.appStoreSubscriptionTransactions.create({
    subscriptionTransactionId: created.id,
    appStoreProductId: transaction.appStoreProductId,
  });
  return created;
};
