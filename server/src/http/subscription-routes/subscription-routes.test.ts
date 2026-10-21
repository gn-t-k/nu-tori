import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { mockAppStoreRootCertificate } from "../../app-store/app-store-root-certificate/app-store-root-certificate.mock";
import {
  type AppStoreTransactionPayload,
  createTestCertificateChain,
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
import { recordPhotographedMeal } from "../../estimation/http/testing/record-photographed-meal";
import { runEstimationAlarm } from "../../estimation/http/testing/run-estimation-alarm";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { mockDeletePostHogPersonOk } from "../../observability/delete-posthog-person/delete-posthog-person.mock";
import { placeFreeTrialLastDay } from "../../subscription-status/http/testing/place-free-trial-last-day";
import { app } from "../app";
import { pullSyncChanges, type PullResult } from "../sync-routes/testing/pull-sync-changes";
import { signInTestAccount } from "../testing";
import { countSubscriptionRows } from "./testing/count-subscription-rows";

describe("購入者のトークンを出す", () => {
  let sessionToken: string;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ sessionToken } = await signInTestAccount(generateRecordId()));
  });

  test("UUID を出して返し、2度目からは同じ値を返すこと", async () => {
    const first = await postAppAccountToken(sessionToken);
    const second = await postAppAccountToken(sessionToken);
    const firstBody = await first.json<{ appAccountToken: string }>();
    expect({
      status: first.status,
      isUuid: /^[\da-f]{8}-[\da-f]{4}-4[\da-f]{3}-[89ab][\da-f]{3}-[\da-f]{12}$/.test(
        firstBody.appAccountToken,
      ),
      second: await second.json(),
    }).toEqual({ status: 200, isUuid: true, second: firstBody });
  });

  test("アカウントごとに別の値を返すこと", async () => {
    const other = await signInTestAccount(generateRecordId());
    const mine = await (await postAppAccountToken(sessionToken)).json();
    const others = await (await postAppAccountToken(other.sessionToken)).json();
    expect(mine).not.toEqual(others);
  });
});

// 時計は実際の時刻より先に置き、張ったアラームがひとりでに動かないようにする
describe("取引を知らせる", () => {
  let chain: TestCertificateChain;
  let appleUserId: string;
  let accountId: string;
  let sessionToken: string;
  let appAccountToken: string;
  let originalTransactionId: string;
  let signTransaction: (overrides?: Partial<AppStoreTransactionPayload>) => Promise<string>;
  let clock: ReturnType<typeof useFakeClock>;
  beforeEach(async () => {
    clock = useFakeClock(Date.parse("2030-01-10T09:00:00Z"));
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    chain = await createTestCertificateChain();
    mockAppStoreRootCertificate(chain.rootCertificate);
    appleUserId = generateRecordId();
    ({ accountId, sessionToken } = await signInTestAccount(appleUserId));
    ({ appAccountToken } = await (
      await postAppAccountToken(sessionToken)
    ).json<{ appAccountToken: string }>());
    // D1 の案内はテストのあいだ消えないので、テストごとに別の元の取引の ID にする
    originalTransactionId = generateRecordId();
    signTransaction = (overrides = {}) =>
      signAppStoreTransaction(chain, {
        transactionId: originalTransactionId,
        originalTransactionId,
        appAccountToken,
        purchaseDate: Date.parse("2030-01-10T09:00:00Z"),
        expiresDate: Date.parse("2030-02-10T09:00:00Z"),
        ...overrides,
      });
  });

  describe("買った直後に知らせたとき", () => {
    let requestId: string;
    let response: Response;
    beforeEach(async () => {
      requestId = generateRecordId();
      response = await postSubscriptionTransaction(sessionToken, {
        requestId,
        signedTransaction: await signTransaction(),
        trigger: "purchase",
      });
    });

    test("結びつけたことと、サブスクリプション中の状態の記録を返すこと", async () => {
      expect({ status: response.status, body: await response.json() }).toMatchObject({
        status: 200,
        body: {
          result: "linked",
          changes: [
            {
              kind: "subscription_status",
              record: {
                type: "regular",
                subscription: {
                  type: "subscribed",
                  plan: "monthly",
                  periodEndsAt: "2030-02-10T09:00:00.000Z",
                },
              },
            },
          ],
        },
      });
    });

    test("受け取り・サブスクリプション・取引・端末の知らせの受け取りを1つずつ書くこと", async () => {
      expect(await countSubscriptionRows(accountId)).toEqual({
        subscription_receipts: 1,
        subscriptions: 1,
        app_store_subscriptions: 1,
        subscription_transactions: 1,
        app_store_subscription_transactions: 1,
        subscription_transaction_report_receipts: 1,
      });
    });

    test("応答と同じ状態の記録が同期でも届くこと", async () => {
      const { changes } = await response.json<{ changes: unknown[] }>();
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
      const { sequence: _, ...lastStatus } = pulled.changes.findLast(
        ({ kind }) => kind === "subscription_status",
      ) ?? { sequence: 0 };
      expect(lastStatus).toEqual(changes[0]);
    });

    describe("同じ要求の ID で送り直したとき", () => {
      let resent: Response;
      beforeEach(async () => {
        resent = await postSubscriptionTransaction(sessionToken, {
          requestId,
          signedTransaction: await signTransaction(),
          trigger: "purchase",
        });
      });

      test("同じ応答を返すこと", async () => {
        expect(await resent.json()).toEqual(await response.json());
      });

      test("何も書かないこと", async () => {
        expect(await countSubscriptionRows(accountId)).toMatchObject({
          subscription_receipts: 1,
          subscription_transaction_report_receipts: 1,
        });
      });
    });

    describe("同じ取引を、別の要求で transaction_updates として知らせたとき", () => {
      beforeEach(async () => {
        await postSubscriptionTransaction(sessionToken, {
          requestId: generateRecordId(),
          signedTransaction: await signTransaction(),
          trigger: "transaction_updates",
        });
      });

      test("受け取りだけを書くこと", async () => {
        expect(await countSubscriptionRows(accountId)).toEqual({
          subscription_receipts: 2,
          subscriptions: 1,
          app_store_subscriptions: 1,
          subscription_transactions: 1,
          app_store_subscription_transactions: 1,
          subscription_transaction_report_receipts: 2,
        });
      });
    });

    describe("同じサブスクリプションの更新の取引を知らせたとき", () => {
      let renewed: Response;
      beforeEach(async () => {
        renewed = await postSubscriptionTransaction(sessionToken, {
          requestId: generateRecordId(),
          signedTransaction: await signTransaction({
            transactionId: generateRecordId(),
            purchaseDate: Date.parse("2030-02-10T09:00:00Z"),
            expiresDate: Date.parse("2030-03-10T09:00:00Z"),
            transactionReason: "RENEWAL",
          }),
          trigger: "transaction_updates",
        });
      });

      test("サブスクリプションは書かず、取引を足すこと", async () => {
        expect(await countSubscriptionRows(accountId)).toMatchObject({
          subscriptions: 1,
          subscription_transactions: 2,
        });
      });

      test("新しい期限の状態を返すこと", async () => {
        expect(await renewed.json()).toMatchObject({
          changes: [{ record: { subscription: { periodEndsAt: "2030-03-10T09:00:00.000Z" } } }],
        });
      });
    });

    describe("取り消しが載った同じ取引の写しを知らせたとき", () => {
      let revoked: Response;
      beforeEach(async () => {
        revoked = await postSubscriptionTransaction(sessionToken, {
          requestId: generateRecordId(),
          signedTransaction: await signTransaction({
            revocationDate: Date.parse("2030-01-15T09:00:00Z"),
          }),
          trigger: "transaction_updates",
        });
      });

      test("取り消しを足し、サブスクリプションの無い状態を返すこと", async () => {
        expect(await revoked.json()).toMatchObject({
          changes: [{ record: { subscription: { type: "none" } } }],
        });
      });
    });

    describe("ほかのアカウントが同じサブスクリプションを復元したとき", () => {
      let other: { accountId: string; sessionToken: string };
      let restored: Response;
      beforeEach(async () => {
        other = await signInTestAccount(generateRecordId());
        restored = await postSubscriptionTransaction(other.sessionToken, {
          requestId: generateRecordId(),
          signedTransaction: await signTransaction({ appAccountToken: undefined }),
          trigger: "restore",
        });
      });

      test("ほかのアカウントのものと返すこと", async () => {
        expect({ status: restored.status, body: await restored.json() }).toEqual({
          status: 200,
          body: { result: "owned_by_other_account" },
        });
      });

      test("何も書かないこと", async () => {
        expect(await countSubscriptionRows(other.accountId)).toMatchObject({
          subscription_receipts: 0,
          subscriptions: 0,
        });
      });
    });

    describe("退会して作り直したアカウントで復元したとき", () => {
      let recreated: { accountId: string; sessionToken: string };
      let restored: Response;
      beforeEach(async () => {
        mockRevokeAppleRefreshTokenOk();
        mockDeletePostHogPersonOk();
        await app.request(
          "/v1/account",
          { method: "DELETE", headers: { authorization: `Bearer ${sessionToken}` } },
          env,
        );
        recreated = await signInTestAccount(appleUserId);
        restored = await postSubscriptionTransaction(recreated.sessionToken, {
          requestId: generateRecordId(),
          signedTransaction: await signTransaction(),
          trigger: "restore",
        });
      });

      test("作り直したアカウントに結びつけること", async () => {
        expect(await restored.json()).toMatchObject({
          result: "linked",
          changes: [
            {
              kind: "subscription_status",
              record: {
                freeTrial: { type: "used_by_earlier_account" },
                subscription: { type: "subscribed" },
              },
            },
          ],
        });
      });
    });
  });

  describe("購入者のトークンがほかの今あるアカウントのものの取引を知らせたとき", () => {
    let response: Response;
    beforeEach(async () => {
      const other = await signInTestAccount(generateRecordId());
      response = await postSubscriptionTransaction(other.sessionToken, {
        requestId: generateRecordId(),
        signedTransaction: await signTransaction(),
        trigger: "restore",
      });
    });

    test("ほかのアカウントのものと返すこと", async () => {
      expect(await response.json()).toEqual({ result: "owned_by_other_account" });
    });

    describe("そのあと購入者のトークンの持ち主が知らせたとき", () => {
      test("結びつけること", async () => {
        const reported = await postSubscriptionTransaction(sessionToken, {
          requestId: generateRecordId(),
          signedTransaction: await signTransaction(),
          trigger: "purchase",
        });
        expect(await reported.json()).toMatchObject({ result: "linked" });
      });
    });
  });

  describe("Sandbox の取引を知らせたとき", () => {
    test("結びつけること", async () => {
      const response = await postSubscriptionTransaction(sessionToken, {
        requestId: generateRecordId(),
        signedTransaction: await signTransaction({ environment: "Sandbox" }),
        trigger: "purchase",
      });
      expect(await response.json()).toMatchObject({ result: "linked" });
    });
  });

  describe("受け付けない取引を知らせたとき", () => {
    test.each([
      {
        name: "署名が差し込んだ根につながらない",
        sign: async () => signAppStoreTransaction(await createTestCertificateChain()),
        code: "transaction_unverified",
      },
      {
        name: "ほかのアプリの取引",
        sign: () => signTransaction({ bundleId: "app.example.other" }),
        code: "transaction_unverified",
      },
      {
        name: "環境が Xcode",
        sign: () => signTransaction({ environment: "Xcode" }),
        code: "environment_unsupported",
      },
      {
        name: "知らない商品",
        sign: () => signTransaction({ productId: "app.nu-tori.unknown" }),
        code: "product_unknown",
      },
    ])("$name なら、$code で断り、何も書かないこと", async ({ sign, code }) => {
      const response = await postSubscriptionTransaction(sessionToken, {
        requestId: generateRecordId(),
        signedTransaction: await sign(),
        trigger: "purchase",
      });
      expect({
        status: response.status,
        body: await response.json(),
        rows: await countSubscriptionRows(accountId),
      }).toMatchObject({
        status: 422,
        body: { code },
        rows: { subscription_receipts: 0 },
      });
    });
  });

  describe("無料体験が終わって保留した食事があるとき", () => {
    let mealId: string;
    let response: Response;
    beforeEach(async () => {
      const today = computeCalendarDayInTimeZone(new Date(), "Asia/Tokyo");
      await placeFreeTrialLastDay(accountId, addDays(today, -10));
      mealId = await recordPhotographedMeal(sessionToken);
      await runEstimationAlarm(accountId);
      clock.advance(60_000);
      response = await postSubscriptionTransaction(sessionToken, {
        requestId: generateRecordId(),
        signedTransaction: await signTransaction(),
        trigger: "purchase",
      });
    });

    test("再開した食事の推定の状態を、サブスクリプションの状態のあとに返すこと", async () => {
      const { changes } = await response.json<{ changes: { kind: string }[] }>();
      expect(changes.map(({ kind }) => kind)).toEqual([
        "subscription_status",
        "meal_estimation_status",
      ]);
      expect(changes[1]).toEqual({
        kind: "meal_estimation_status",
        recordId: mealId,
        record: { mealId, status: "estimating" },
      });
    });

    test("再開した予定の時刻（買ったとき）にアラームを張り直すこと", async () => {
      const alarm = await runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
        state.storage.getAlarm(),
      );
      expect(alarm).toBe(Date.parse("2030-01-10T09:01:00Z"));
    });
  });
});

const postSubscriptionTransaction = (
  sessionToken: string,
  body: { requestId: string; signedTransaction: string; trigger: string },
) =>
  app.request(
    "/v1/subscription-transactions",
    {
      method: "POST",
      headers: { authorization: `Bearer ${sessionToken}`, "content-type": "application/json" },
      body: JSON.stringify(body),
    },
    env,
  );

const postAppAccountToken = (sessionToken: string) =>
  app.request(
    "/v1/app-account-token",
    { method: "POST", headers: { authorization: `Bearer ${sessionToken}` } },
    env,
  );
