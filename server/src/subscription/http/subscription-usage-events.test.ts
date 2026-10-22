import { runDurableObjectAlarm, runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test, vi } from "vitest";
import { mockReadAppStoreRootCertificateOk } from "../../app-store/app-store-root-certificate/read-app-store-root-certificate.mock";
import {
  type AppStoreTransactionPayload,
  createTestCertificateChain,
  signAppStoreServerNotification,
  signAppStoreTransaction,
  type TestCertificateChain,
} from "../../app-store/testing";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockRevokeAppleRefreshTokenOk } from "../../auth/revoke-apple-refresh-token/revoke-apple-refresh-token.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { addDays } from "../../domain/add-days";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { generateRecordId } from "../../domain/record-id";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { app } from "../../http/app";
import { enableUsageEventSending } from "../../http/sync-routes/testing/enable-usage-event-sending";
import { signInTestAccount } from "../../http/testing";
import { mockDeletePostHogPersonOk } from "../../observability/delete-posthog-person/delete-posthog-person.mock";
import { mockPostHogCaptureEndpointOk } from "../../observability/testing/posthog-capture-endpoint.mock";
import { readPostHogCapturedEvents } from "../../observability/testing/read-posthog-captured-events";
import { markTestUser } from "../../subscription-status/http/testing/mark-test-user";
import { placeFreeTrialLastDay } from "../../subscription-status/http/testing/place-free-trial-last-day";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { createWeightRecordWrite } from "../../weight-record/http/testing/create-weight-record-write";

// 時計は実際の時刻より先に置き、張ったアラームがひとりでに動かないようにする
describe("サブスクリプションの利用状況の出来事", () => {
  let chain: TestCertificateChain;
  let appleUserId: string;
  let accountId: string;
  let sessionToken: string;
  let appAccountToken: string;
  let originalTransactionId: string;
  let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
  beforeEach(async () => {
    useFakeClock(Date.parse("2030-01-10T09:00:00Z"));
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    chain = await createTestCertificateChain();
    mockReadAppStoreRootCertificateOk(chain.rootCertificate);
    appleUserId = generateRecordId();
    ({ accountId, sessionToken } = await signInTestAccount(appleUserId));
    ({ appAccountToken } = await (
      await app.request(
        "/v1/app-account-token",
        { method: "POST", headers: { authorization: `Bearer ${sessionToken}` } },
        env,
      )
    ).json<{ appAccountToken: string }>());
    // D1 の案内はテストのあいだ消えないので、テストごとに別の元の取引の ID にする
    originalTransactionId = generateRecordId();
    await enableUsageEventSending(accountId);
    captureSpy = mockPostHogCaptureEndpointOk();
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

  const reportTransaction = async (overrides: Partial<AppStoreTransactionPayload> = {}) =>
    app.request(
      "/v1/subscription-transactions",
      {
        method: "POST",
        headers: { authorization: `Bearer ${sessionToken}`, "content-type": "application/json" },
        body: JSON.stringify({
          requestId: generateRecordId(),
          signedTransaction: await signTransaction(overrides),
          trigger: "purchase",
        }),
      },
      env,
    );

  const postNotification = async (notification: {
    notificationType: string;
    subtype?: string | undefined;
    signedTransactionInfo: string;
    environment?: string;
  }) => {
    const { signedTransactionInfo, environment = "Production", ...rest } = notification;
    return app.request(
      "/v1/app-store-server-notifications",
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          signedPayload: await signAppStoreServerNotification(chain, {
            notificationUUID: generateRecordId(),
            signedDate: Date.parse("2030-01-10T09:00:01Z"),
            subtype: undefined,
            ...rest,
            data: { bundleId: env.APPLE_BUNDLE_ID, environment, signedTransactionInfo },
          }),
        }),
      },
      env,
    );
  };

  const endFreeTrial = () =>
    placeFreeTrialLastDay(
      accountId,
      addDays(computeCalendarDayInTimeZone(new Date(), "Asia/Tokyo"), -10),
    );

  const runAlarmAt = async (time: string) => {
    vi.setSystemTime(Date.parse(time));
    captureSpy.mockClear();
    await runDurableObjectAlarm(getAccountDurableObject(env, accountId));
  };

  const readSubscriptionEvents = () =>
    readPostHogCapturedEvents(captureSpy).filter(({ event }) => event.startsWith("subscription_"));

  describe("無料体験中に買った取引を端末が知らせたとき", () => {
    beforeEach(async () => {
      await reportTransaction();
    });

    test("始まった出来事を、無料体験中に買った旗を立てて送ること", () => {
      expect(readSubscriptionEvents()).toEqual([
        {
          event: "subscription_started",
          distinct_id: accountId,
          properties: {
            purchased_during_free_trial: true,
            rebuilt_account: false,
            $geoip_disable: true,
          },
        },
      ]);
    });

    describe("同じ取引をもう一度知らせたとき", () => {
      beforeEach(async () => {
        captureSpy.mockClear();
        await reportTransaction();
      });

      test("もう一度は送らないこと", () => {
        expect(readSubscriptionEvents()).toEqual([]);
      });
    });

    describe("更新の取引を知らせたとき", () => {
      beforeEach(async () => {
        captureSpy.mockClear();
        await reportTransaction({
          transactionId: generateRecordId(),
          purchaseDate: Date.parse("2030-02-10T09:00:00Z"),
          expiresDate: Date.parse("2030-03-10T09:00:00Z"),
          transactionReason: "RENEWAL",
        });
      });

      test("更新した出来事を送ること", () => {
        expect(readSubscriptionEvents()).toEqual([
          {
            event: "subscription_renewed",
            distinct_id: accountId,
            properties: { $geoip_disable: true },
          },
        ]);
      });
    });
  });

  describe("Sandbox の取引を端末が知らせたとき", () => {
    beforeEach(async () => {
      await reportTransaction({ environment: "Sandbox" });
    });

    test("送らないこと", () => {
      expect(readSubscriptionEvents()).toEqual([]);
    });
  });

  describe("最初の購入の通知が端末の知らせより先に届いたとき", () => {
    beforeEach(async () => {
      await postNotification({
        notificationType: "SUBSCRIBED",
        subtype: "INITIAL_BUY",
        signedTransactionInfo: await signTransaction(),
      });
      await reportTransaction();
    });

    test("始まった出来事を1度だけ送ること", () => {
      expect(readSubscriptionEvents().map(({ event }) => event)).toEqual(["subscription_started"]);
    });
  });

  describe("更新の通知が届いたとき", () => {
    beforeEach(async () => {
      await reportTransaction();
      captureSpy.mockClear();
      await postNotification({
        notificationType: "DID_RENEW",
        signedTransactionInfo: await signTransaction({
          transactionId: generateRecordId(),
          purchaseDate: Date.parse("2030-02-10T09:00:00Z"),
          expiresDate: Date.parse("2030-03-10T09:00:00Z"),
          transactionReason: "RENEWAL",
        }),
      });
    });

    test("更新した出来事を送ること", () => {
      expect(readSubscriptionEvents().map(({ event }) => event)).toEqual(["subscription_renewed"]);
    });
  });

  describe("無料体験が終わってから買ったとき", () => {
    beforeEach(async () => {
      await endFreeTrial();
      await reportTransaction();
    });

    test("無料体験中に買った旗を下ろして送ること", () => {
      expect(readSubscriptionEvents()).toMatchObject([
        {
          event: "subscription_started",
          properties: { purchased_during_free_trial: false },
        },
      ]);
    });

    test("商品の ID・価格・取引の ID・購入者のトークンを送らないこと", () => {
      const sent = JSON.stringify(readPostHogCapturedEvents(captureSpy));
      expect(
        [
          "app.nu-tori.subscription.monthly",
          "480000",
          originalTransactionId,
          appAccountToken,
        ].filter((value) => sent.includes(value)),
      ).toEqual([]);
    });

    describe("そのあと返金されたとき", () => {
      beforeEach(async () => {
        captureSpy.mockClear();
        await postNotification({
          notificationType: "REFUND",
          signedTransactionInfo: await signTransaction({
            revocationDate: Date.parse("2030-01-12T09:00:00Z"),
          }),
        });
      });

      test("切れた出来事を、買ったことがあり取り消しによる旗を立てて送ること", () => {
        expect(readSubscriptionEvents()).toEqual([
          {
            event: "subscription_expired",
            distinct_id: accountId,
            properties: {
              has_purchased: true,
              by_revocation: true,
              rebuilt_account: false,
              $geoip_disable: true,
            },
          },
        ]);
      });
    });
  });

  describe("無料体験中に買って返金されたとき", () => {
    beforeEach(async () => {
      await reportTransaction();
      captureSpy.mockClear();
      await postNotification({
        notificationType: "REFUND",
        signedTransactionInfo: await signTransaction({
          revocationDate: Date.parse("2030-01-12T09:00:00Z"),
        }),
      });
    });

    test("無料体験で使えるので、切れた出来事を送らないこと", () => {
      expect(readSubscriptionEvents()).toEqual([]);
    });
  });

  describe("利用状況を送らない設定のとき", () => {
    beforeEach(async () => {
      await runInDurableObject(getAccountDurableObject(env, accountId), (_, state) => {
        state.storage.sql.exec(
          "INSERT INTO account_settings (id, sends_usage_data) VALUES (?, 0)",
          generateRecordId(),
        );
      });
      await reportTransaction();
    });

    test("送らないこと", () => {
      expect(readSubscriptionEvents()).toEqual([]);
    });
  });

  // 同期の要求は Asia/Tokyo で送る
  describe("課金の仕事のアラーム", () => {
    let lastDay: string;
    beforeEach(async () => {
      lastDay = addDays(computeCalendarDayInTimeZone(new Date(), "Asia/Tokyo"), 3);
      await placeFreeTrialLastDay(accountId, lastDay);
      await pushSyncWrites(sessionToken, { writes: [createWeightRecordWrite()] });
    });

    describe("無料体験の終わり（最後の日の次の日の 0:00）のあとに動いたとき", () => {
      beforeEach(async () => {
        await runAlarmAt(`${addDays(lastDay, 1)}T00:00:00+09:00`);
      });

      test("切れた出来事を、買ったことの無い旗で送ること", () => {
        expect(readSubscriptionEvents()).toEqual([
          {
            event: "subscription_expired",
            distinct_id: accountId,
            properties: {
              has_purchased: false,
              by_revocation: false,
              rebuilt_account: false,
              $geoip_disable: true,
            },
          },
        ]);
      });
    });

    describe("無料体験の終わりから24時間を過ぎて動いたとき", () => {
      beforeEach(async () => {
        await runAlarmAt(`${addDays(lastDay, 2)}T00:00:00+09:00`);
      });

      test("送らないこと", () => {
        expect(readSubscriptionEvents()).toEqual([]);
      });
    });

    describe("最後の日の 0:00 に動いたとき", () => {
      beforeEach(async () => {
        await runAlarmAt(`${lastDay}T00:00:00+09:00`);
      });

      test("まだ使えるので送らないこと", () => {
        expect(readSubscriptionEvents()).toEqual([]);
      });
    });

    describe("テストユーザーで、無料体験の終わりのあとに動いたとき", () => {
      beforeEach(async () => {
        await markTestUser(accountId);
        await runAlarmAt(`${addDays(lastDay, 1)}T00:00:00+09:00`);
      });

      test("送らないこと", () => {
        expect(readSubscriptionEvents()).toEqual([]);
      });
    });

    describe("無料体験中に買ったサブスクリプションの終わりのあとに動いたとき", () => {
      let expiresAt: string;
      beforeEach(async () => {
        expiresAt = `${addDays(lastDay, 10)}T12:00:00+09:00`;
        await reportTransaction({ expiresDate: Date.parse(expiresAt) });
        await runAlarmAt(expiresAt);
      });

      test("切れた出来事を、買ったことのある旗で送ること", () => {
        expect(readSubscriptionEvents()).toMatchObject([
          { event: "subscription_expired", properties: { has_purchased: true } },
        ]);
      });
    });

    describe("Sandbox のサブスクリプションの終わりのあとに動いたとき", () => {
      beforeEach(async () => {
        const expiresAt = `${addDays(lastDay, 10)}T12:00:00+09:00`;
        await reportTransaction({ expiresDate: Date.parse(expiresAt), environment: "Sandbox" });
        await runAlarmAt(expiresAt);
      });

      test("送らないこと", () => {
        expect(readSubscriptionEvents()).toEqual([]);
      });
    });
  });

  describe("退会して、同じ Apple ID で作り直したアカウントに最初にサインインしたとき", () => {
    let recreatedAccountId: string;
    beforeEach(async () => {
      mockRevokeAppleRefreshTokenOk();
      mockDeletePostHogPersonOk();
      await app.request(
        "/v1/account",
        { method: "DELETE", headers: { authorization: `Bearer ${sessionToken}` } },
        env,
      );
      // サインインの Apple の鍵の取り出しは通し、PostHog への送りは受け取る
      const fetchSpy = mockAppleKeysEndpointOk();
      const fetchAppleKeys = fetchSpy.getMockImplementation();
      captureSpy = fetchSpy.mockImplementation(async (input, init) =>
        (input instanceof Request ? input.url : String(input)).startsWith(
          "https://eu.i.posthog.com/",
        )
          ? Response.json({ status: 1 })
          : (fetchAppleKeys ?? fetch)(input, init),
      );
      ({ accountId: recreatedAccountId } = await signInTestAccount(appleUserId));
    });

    test("切れた出来事を、作り直したアカウントの旗を立てて送ること", () => {
      expect(readSubscriptionEvents()).toEqual([
        {
          event: "subscription_expired",
          distinct_id: recreatedAccountId,
          properties: {
            has_purchased: false,
            by_revocation: false,
            rebuilt_account: true,
            $geoip_disable: true,
          },
        },
      ]);
    });
  });
});
