import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { mockReadAppStoreRootCertificateOk } from "../../app-store/app-store-root-certificate/read-app-store-root-certificate.mock";
import {
  type AppStoreTransactionPayload,
  createTestCertificateChain,
  signAppStoreRenewalInfo,
  signAppStoreServerNotification,
  signAppStoreTransaction,
  type TestCertificateChain,
} from "../../app-store/testing";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { addDays } from "../../domain/add-days";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { generateRecordId } from "../../domain/record-id";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { recordPhotographedMeal } from "../../estimation/http/testing/record-photographed-meal";
import { runEstimationAlarm } from "../../estimation/http/testing/run-estimation-alarm";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { placeFreeTrialLastDay } from "../../subscription-status/http/testing/place-free-trial-last-day";
import { app } from "../app";
import { pullSyncChanges, type PullResult } from "../sync-routes/testing/pull-sync-changes";
import { signInTestAccount } from "../testing";
import { countNotificationRows } from "./testing/count-notification-rows";

// 時計は実際の時刻より先に置き、張ったアラームがひとりでに動かないようにする
describe("App Store のサーバー通知を受ける", () => {
  let chain: TestCertificateChain;
  let accountId: string;
  let sessionToken: string;
  let appAccountToken: string;
  let originalTransactionId: string;
  let clock: ReturnType<typeof useFakeClock>;
  beforeEach(async () => {
    clock = useFakeClock(Date.parse("2030-01-10T09:00:00Z"));
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    chain = await createTestCertificateChain();
    mockReadAppStoreRootCertificateOk(chain.rootCertificate);
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
    ({ appAccountToken } = await (
      await app.request(
        "/v1/app-account-token",
        { method: "POST", headers: { authorization: `Bearer ${sessionToken}` } },
        env,
      )
    ).json<{ appAccountToken: string }>());
    // D1 の案内はテストのあいだ消えないので、テストごとに別の元の取引の ID にする
    originalTransactionId = generateRecordId();
  });

  // 最初の取引（2030-01-10 に買った月額）
  const signTransaction = (overrides: Partial<AppStoreTransactionPayload> = {}) =>
    signAppStoreTransaction(chain, {
      transactionId: originalTransactionId,
      originalTransactionId,
      appAccountToken,
      purchaseDate: Date.parse("2030-01-10T09:00:00Z"),
      expiresDate: Date.parse("2030-02-10T09:00:00Z"),
      ...overrides,
    });

  // 更新の取引（2030-02-10 から 2030-03-10）
  const signRenewal = (overrides: Partial<AppStoreTransactionPayload> = {}) =>
    signTransaction({
      transactionId: `${originalTransactionId}-renewal`,
      purchaseDate: Date.parse("2030-02-10T09:00:00Z"),
      expiresDate: Date.parse("2030-03-10T09:00:00Z"),
      transactionReason: "RENEWAL",
      ...overrides,
    });

  const postNotification = async (notification: {
    notificationType: string;
    subtype?: string | undefined;
    notificationUUID?: string;
    signedDate?: number;
    signedTransactionInfo?: string | undefined;
    signedRenewalInfo?: string | undefined;
    bundleId?: string;
    environment?: string;
  }) => {
    const {
      signedTransactionInfo,
      signedRenewalInfo,
      bundleId = env.APPLE_BUNDLE_ID,
      environment = "Production",
      ...rest
    } = notification;
    const signedPayload = await signAppStoreServerNotification(chain, {
      notificationUUID: generateRecordId(),
      signedDate: Date.parse("2030-01-10T09:00:01Z"),
      subtype: undefined,
      ...rest,
      data: { bundleId, environment, signedTransactionInfo, signedRenewalInfo },
    });
    return postSignedPayload(signedPayload);
  };

  const postSubscribed = async () =>
    postNotification({
      notificationType: "SUBSCRIBED",
      subtype: "INITIAL_BUY",
      signedTransactionInfo: await signTransaction(),
    });

  const readSubscription = async () => {
    const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
    return pulled.changes.findLast(({ kind }) => kind === "subscription_status")?.record?.[
      "subscription"
    ];
  };

  const postRefund = async (revocationDate: number) =>
    postNotification({
      notificationType: "REFUND",
      signedTransactionInfo: await signTransaction({ revocationDate }),
    });

  const postRefundReversed = async () =>
    postNotification({
      notificationType: "REFUND_REVERSED",
      signedTransactionInfo: await signTransaction(),
    });

  describe("最初の購入の通知が、端末の知らせより先に届いたとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await postSubscribed();
    });

    test("200 を返し、購入者のトークンのアカウントでサブスクリプション中になること", async () => {
      expect({ status: response.status, subscription: await readSubscription() }).toEqual({
        status: 200,
        subscription: subscribedUntil("2030-02-10T09:00:00.000Z"),
      });
    });

    test("受け取り・通知の受け取り・サブスクリプション・取引を1つずつ書くこと", async () => {
      expect(await countNotificationRows(accountId)).toMatchObject({
        subscription_receipts: 1,
        app_store_notification_receipts: 1,
        subscriptions: 1,
        subscription_transactions: 1,
      });
    });

    describe("あとで端末が同じ取引を知らせたとき", () => {
      let reported: Response;
      beforeEach(async () => {
        reported = await app.request(
          "/v1/subscription-transactions",
          {
            method: "POST",
            headers: {
              authorization: `Bearer ${sessionToken}`,
              "content-type": "application/json",
            },
            body: JSON.stringify({
              requestId: generateRecordId(),
              signedTransaction: await signTransaction(),
              trigger: "purchase",
            }),
          },
          env,
        );
      });

      test("結びつけ、端末の知らせが先のときと同じ状態を返すこと", async () => {
        expect(await reported.json()).toMatchObject({
          result: "linked",
          changes: [{ record: { subscription: subscribedUntil("2030-02-10T09:00:00.000Z") } }],
        });
      });

      test("取引を書き足さないこと", async () => {
        expect(await countNotificationRows(accountId)).toMatchObject({
          subscription_receipts: 2,
          subscription_transactions: 1,
        });
      });
    });

    describe("同じ notificationUUID の通知がまた届いたとき", () => {
      test("200 を返し、何も書かないこと", async () => {
        const notificationUUID = generateRecordId();
        const signedTransactionInfo = await signRenewal();
        await postNotification({
          notificationType: "DID_RENEW",
          notificationUUID,
          signedTransactionInfo,
        });
        const before = await countNotificationRows(accountId);
        const resent = await postNotification({
          notificationType: "DID_RENEW",
          notificationUUID,
          signedTransactionInfo,
        });
        expect({ status: resent.status, rows: await countNotificationRows(accountId) }).toEqual({
          status: 200,
          rows: before,
        });
      });
    });

    describe("購入者のトークンの無い更新の通知が届いたとき", () => {
      test("元の取引の ID の案内で引き、更新した期限になること", async () => {
        await postNotification({
          notificationType: "DID_RENEW",
          signedTransactionInfo: await signRenewal({ appAccountToken: undefined }),
        });
        expect(await readSubscription()).toEqual(subscribedUntil("2030-03-10T09:00:00.000Z"));
      });
    });

    describe("同じ取引の古い写しが、更新のあとに届いたとき", () => {
      test("最初の写しのまま書き換えないこと", async () => {
        await postNotification({
          notificationType: "DID_RENEW",
          signedTransactionInfo: await signRenewal(),
        });
        await postNotification({
          notificationType: "DID_CHANGE_RENEWAL_PREF",
          signedTransactionInfo: await signRenewal({
            expiresDate: Date.parse("2030-02-20T09:00:00Z"),
          }),
        });
        expect(await readSubscription()).toEqual(subscribedUntil("2030-03-10T09:00:00.000Z"));
      });
    });

    describe("更新の請求に失敗して猶予に入ったとき", () => {
      let failed: Response;
      beforeEach(async () => {
        failed = await postNotification({
          notificationType: "DID_FAIL_TO_RENEW",
          subtype: "GRACE_PERIOD",
          signedDate: Date.parse("2030-02-10T09:00:01Z"),
          signedTransactionInfo: await signTransaction(),
          signedRenewalInfo: await signAppStoreRenewalInfo(chain, {
            originalTransactionId,
            gracePeriodExpiresDate: Date.parse("2030-02-26T09:00:00Z"),
          }),
        });
      });

      test("失敗した更新の前の期間の取引に、請求の失敗と猶予を書くこと", async () => {
        expect({
          status: failed.status,
          rows: await countNotificationRows(accountId),
        }).toMatchObject({
          status: 200,
          rows: {
            subscription_transactions: 1,
            subscription_billing_failures: 1,
            subscription_grace_periods: 1,
          },
        });
      });

      test("猶予の終わりを持つ状態になること", async () => {
        expect(await readSubscription()).toEqual(
          subscribedUntil("2030-02-10T09:00:00.000Z", {
            type: "granted",
            endsAt: "2030-02-26T09:00:00.000Z",
          }),
        );
      });

      describe("猶予が終わった通知が届いたとき", () => {
        test("受け取りだけを書き、猶予の終わりを持つ状態のままにすること", async () => {
          await postNotification({
            notificationType: "GRACE_PERIOD_EXPIRED",
            signedTransactionInfo: await signTransaction(),
          });
          expect({
            rows: await countNotificationRows(accountId),
            subscription: await readSubscription(),
          }).toEqual({
            rows: {
              subscription_receipts: 3,
              app_store_notification_receipts: 3,
              subscriptions: 1,
              subscription_transactions: 1,
              subscription_transaction_revocations: 0,
              subscription_transaction_revocation_reversals: 0,
              subscription_billing_failures: 1,
              subscription_grace_periods: 1,
            },
            subscription: subscribedUntil("2030-02-10T09:00:00.000Z", {
              type: "granted",
              endsAt: "2030-02-26T09:00:00.000Z",
            }),
          });
        });
      });
    });

    describe("請求の失敗が、請求を取り戻した更新より遅れて届いたとき", () => {
      test("取り戻した更新の期限の状態のままにすること", async () => {
        await postNotification({
          notificationType: "DID_RENEW",
          subtype: "BILLING_RECOVERY",
          signedTransactionInfo: await signRenewal({
            purchaseDate: Date.parse("2030-02-15T09:00:00Z"),
            expiresDate: Date.parse("2030-03-15T09:00:00Z"),
          }),
        });
        await postNotification({
          notificationType: "DID_FAIL_TO_RENEW",
          subtype: "GRACE_PERIOD",
          signedTransactionInfo: await signTransaction(),
          signedRenewalInfo: await signAppStoreRenewalInfo(chain, {
            originalTransactionId,
            gracePeriodExpiresDate: Date.parse("2030-02-26T09:00:00Z"),
          }),
        });
        expect(await readSubscription()).toEqual(subscribedUntil("2030-03-15T09:00:00.000Z"));
      });
    });

    describe("返金と、返金の取り消しと、また取り消しが届いたとき", () => {
      test("返金で取引が取り消され、サブスクリプションが無くなること", async () => {
        await postRefund(firstRevocationDate);
        expect(await readSubscription()).toEqual({ type: "none" });
      });

      test("返金の取り消しで、またサブスクリプション中になること", async () => {
        await postRefund(firstRevocationDate);
        await postRefundReversed();
        expect(await readSubscription()).toEqual(subscribedUntil("2030-02-10T09:00:00.000Z"));
      });

      test("同じ取り消しの時刻の返金がまた届いても、取り消しを足さないこと", async () => {
        await postRefund(firstRevocationDate);
        await postRefundReversed();
        await postRefund(firstRevocationDate);
        expect({
          rows: await countNotificationRows(accountId),
          subscription: await readSubscription(),
        }).toMatchObject({
          rows: {
            subscription_transaction_revocations: 1,
            subscription_transaction_revocation_reversals: 1,
          },
          subscription: subscribedUntil("2030-02-10T09:00:00.000Z"),
        });
      });

      test("取り消しの時刻が違う新しい取り消しで、またサブスクリプションが無くなること", async () => {
        await postRefund(firstRevocationDate);
        await postRefundReversed();
        await postRefund(secondRevocationDate);
        expect({
          rows: await countNotificationRows(accountId),
          subscription: await readSubscription(),
        }).toMatchObject({
          rows: { subscription_transaction_revocations: 2 },
          subscription: { type: "none" },
        });
      });

      describe("返金の取り消しが、返金より先に届いたとき", () => {
        test("500 を返し、何も書かないこと", async () => {
          const before = await countNotificationRows(accountId);
          const reversed = await postRefundReversed();
          expect({
            status: reversed.status,
            rows: await countNotificationRows(accountId),
          }).toEqual({ status: 500, rows: before });
        });

        test("返金のあとの送り直しで、返金を戻すこと", async () => {
          const notificationUUID = generateRecordId();
          const signedTransactionInfo = await signTransaction();
          await postNotification({
            notificationType: "REFUND_REVERSED",
            notificationUUID,
            signedTransactionInfo,
          });
          await postRefund(firstRevocationDate);
          const resent = await postNotification({
            notificationType: "REFUND_REVERSED",
            notificationUUID,
            signedTransactionInfo,
          });
          expect({ status: resent.status, subscription: await readSubscription() }).toEqual({
            status: 200,
            subscription: subscribedUntil("2030-02-10T09:00:00.000Z"),
          });
        });
      });
    });

    describe.each(["EXPIRED", "DID_CHANGE_RENEWAL_STATUS"])("%s の通知が届いたとき", (type) => {
      test("受け取りだけを書くこと", async () => {
        await postNotification({
          notificationType: type,
          signedTransactionInfo: await signTransaction(),
        });
        expect(await countNotificationRows(accountId)).toMatchObject({
          subscription_receipts: 2,
          app_store_notification_receipts: 2,
          subscription_transactions: 1,
        });
      });
    });
  });

  describe("案内も購入者のトークンの持ち主も無い通知が届いたとき", () => {
    test("200 を返し、案内を書かないこと", async () => {
      const response = await postNotification({
        notificationType: "SUBSCRIBED",
        subtype: "INITIAL_BUY",
        signedTransactionInfo: await signTransaction({ appAccountToken: generateRecordId() }),
      });
      const route = await env.DB.prepare(
        "SELECT count(*) AS count FROM app_store_subscription_routes WHERE app_store_original_transaction_id = ?",
      )
        .bind(originalTransactionId)
        .first<{ count: number }>();
      expect({ status: response.status, routes: route?.count }).toEqual({
        status: 200,
        routes: 0,
      });
    });
  });

  describe("取引を運ばない通知が届いたとき", () => {
    test("200 を返すこと", async () => {
      const response = await postNotification({ notificationType: "TEST" });
      expect(response.status).toBe(200);
    });
  });

  describe("受け付けない通知が届いたとき", () => {
    test.each([
      {
        name: "署名が差し込んだ根につながらない",
        post: async () =>
          postSignedPayload(
            await signAppStoreServerNotification(await createTestCertificateChain()),
          ),
      },
      {
        name: "取引の署名が差し込んだ根につながらない",
        post: async () =>
          postNotification({
            notificationType: "SUBSCRIBED",
            signedTransactionInfo: await signAppStoreTransaction(
              await createTestCertificateChain(),
              { originalTransactionId, appAccountToken },
            ),
          }),
      },
      {
        name: "ほかのアプリの通知",
        post: async () =>
          postNotification({
            notificationType: "SUBSCRIBED",
            bundleId: "app.example.other",
            signedTransactionInfo: await signTransaction(),
          }),
      },
      {
        name: "ほかのアプリの取引",
        post: async () =>
          postNotification({
            notificationType: "SUBSCRIBED",
            signedTransactionInfo: await signTransaction({ bundleId: "app.example.other" }),
          }),
      },
      {
        name: "環境が Xcode の取引",
        post: async () =>
          postNotification({
            notificationType: "SUBSCRIBED",
            environment: "Xcode",
            signedTransactionInfo: await signTransaction({ environment: "Xcode" }),
          }),
      },
    ])("$name なら、400 で断り、何も書かないこと", async ({ post }) => {
      const response = await post();
      expect({
        status: response.status,
        rows: await countNotificationRows(accountId),
      }).toMatchObject({ status: 400, rows: { subscription_receipts: 0 } });
    });
  });

  describe("無料体験が終わって保留した食事があるとき", () => {
    beforeEach(async () => {
      const today = computeCalendarDayInTimeZone(new Date(), "Asia/Tokyo");
      await placeFreeTrialLastDay(accountId, addDays(today, -10));
      await recordPhotographedMeal(sessionToken);
      await runEstimationAlarm(accountId);
      clock.advance(60_000);
      await postSubscribed();
    });

    test("買った取引を書いたら推定を再開し、再開した予定の時刻にアラームを張り直すこと", async () => {
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
      const alarm = await runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
        state.storage.getAlarm(),
      );
      expect({
        status: pulled.changes.findLast(({ kind }) => kind === "meal_estimation_status")?.record,
        alarm,
      }).toMatchObject({
        status: { status: "estimating" },
        alarm: Date.parse("2030-01-10T09:01:00Z"),
      });
    });
  });
});

const firstRevocationDate = Date.parse("2030-01-15T09:00:00Z");
const secondRevocationDate = Date.parse("2030-01-20T09:00:00Z");

const subscribedUntil = (periodEndsAt: string, billingGrace: unknown = { type: "none" }) => ({
  type: "subscribed",
  plan: "monthly",
  periodEndsAt,
  billingGrace,
});

const postSignedPayload = (signedPayload: string) =>
  app.request(
    "/v1/app-store-server-notifications",
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ signedPayload }),
    },
    env,
  );
