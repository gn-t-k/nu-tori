import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { mockAppStoreRootCertificate } from "../../app-store/app-store-root-certificate/app-store-root-certificate.mock";
import {
  type AppStoreTransactionPayload,
  createTestCertificateChain,
  signAppStoreServerNotification,
  signAppStoreTransaction,
  type TestCertificateChain,
} from "../../app-store/testing";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { generateRecordId } from "../../domain/record-id";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { app } from "../../http/app";
import { signInTestAccount } from "../../http/testing";
import { mockCaptureExceptionOk } from "../../observability/capture-exception.mock";

// Sentry に送る、App Store のサーバー通知と取引の知らせの失敗（#647 の「観測」）
describe("サブスクリプションの失敗の Sentry への報告", () => {
  let chain: TestCertificateChain;
  let appleUserId: string;
  let sessionToken: string;
  let appAccountToken: string;
  let originalTransactionId: string;
  let captureExceptionSpy: ReturnType<typeof mockCaptureExceptionOk>;
  beforeEach(async () => {
    useFakeClock(Date.parse("2030-01-10T09:00:00Z"));
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    chain = await createTestCertificateChain();
    mockAppStoreRootCertificate(chain.rootCertificate);
    appleUserId = generateRecordId();
    ({ sessionToken } = await signInTestAccount(appleUserId));
    ({ appAccountToken } = await (
      await app.request(
        "/v1/app-account-token",
        { method: "POST", headers: { authorization: `Bearer ${sessionToken}` } },
        env,
      )
    ).json<{ appAccountToken: string }>());
    originalTransactionId = generateRecordId();
    captureExceptionSpy = mockCaptureExceptionOk();
  });

  const signTransaction = (overrides: Partial<AppStoreTransactionPayload> = {}) =>
    signAppStoreTransaction(chain, {
      transactionId: originalTransactionId,
      originalTransactionId,
      appAccountToken,
      purchaseDate: Date.parse("2030-01-10T09:00:00Z"),
      expiresDate: Date.parse("2030-02-10T09:00:00Z"),
      ...overrides,
    });

  const reportTransaction = (signedTransaction: string) =>
    app.request(
      "/v1/subscription-transactions",
      {
        method: "POST",
        headers: { authorization: `Bearer ${sessionToken}`, "content-type": "application/json" },
        body: JSON.stringify({
          requestId: generateRecordId(),
          signedTransaction,
          trigger: "purchase",
        }),
      },
      env,
    );

  // 送ったものに、署名つきの本文・購入者のトークン・Apple の sub が無いか
  const readSentSecrets = (signed: string) => {
    const sent = JSON.stringify(captureExceptionSpy.mock.calls);
    return [signed, appAccountToken, appleUserId].filter((value) => sent.includes(value));
  };

  describe("署名を確かめられない通知が届いたとき", () => {
    let signedPayload: string;
    beforeEach(async () => {
      signedPayload = await signNotification(await createTestCertificateChain(), {
        environment: "Production",
        signedTransactionInfo: await signTransaction(),
      });
      await postSignedPayload(signedPayload);
    });

    test("確かめられなかったことを、本文を含めずに送ること", () => {
      expect({
        calls: captureExceptionSpy.mock.calls,
        secrets: readSentSecrets(signedPayload),
      }).toEqual({
        calls: [
          [
            expect.objectContaining({
              name: "AppStoreServerNotificationUnhandledError",
              reason: "unverified",
            }),
          ],
        ],
        secrets: [],
      });
    });
  });

  describe("Production の環境の、案内できない通知が届いたとき", () => {
    let signedPayload: string;
    beforeEach(async () => {
      signedPayload = await signNotification(chain, {
        environment: "Production",
        signedTransactionInfo: await signTransaction({ appAccountToken: undefined }),
      });
      await postSignedPayload(signedPayload);
    });

    test("案内できなかったことを、通知の種類を添え、本文を含めずに送ること", () => {
      expect({
        calls: captureExceptionSpy.mock.calls,
        secrets: readSentSecrets(signedPayload),
      }).toEqual({
        calls: [
          [
            expect.objectContaining({
              name: "AppStoreServerNotificationUnhandledError",
              reason: "unrouted",
              notificationType: "SUBSCRIBED",
              notificationSubtype: "INITIAL_BUY",
            }),
          ],
        ],
        secrets: [],
      });
    });
  });

  describe("Sandbox の環境の、案内できない通知が届いたとき", () => {
    beforeEach(async () => {
      await postSignedPayload(
        await signNotification(chain, {
          environment: "Sandbox",
          signedTransactionInfo: await signTransaction({
            appAccountToken: undefined,
            environment: "Sandbox",
          }),
        }),
      );
    });

    test("送らないこと", () => {
      expect(captureExceptionSpy).not.toHaveBeenCalled();
    });
  });

  describe("署名を確かめられない取引を端末が知らせたとき", () => {
    let signedTransaction: string;
    beforeEach(async () => {
      signedTransaction = await signAppStoreTransaction(await createTestCertificateChain(), {
        appAccountToken,
      });
      await reportTransaction(signedTransaction);
    });

    test("知らせの失敗を、断った理由を添え、本文を含めずに送ること", () => {
      expect({
        calls: captureExceptionSpy.mock.calls,
        secrets: readSentSecrets(signedTransaction),
      }).toEqual({
        calls: [
          [
            expect.objectContaining({
              name: "SubscriptionTransactionReportFailedError",
              code: "transaction_unverified",
            }),
          ],
        ],
        secrets: [],
      });
    });
  });

  describe("知らない商品の取引を端末が知らせたとき", () => {
    beforeEach(async () => {
      await reportTransaction(await signTransaction({ productId: "app.nu-tori.unknown" }));
    });

    test("知らせの失敗を送ること", () => {
      expect(captureExceptionSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          name: "SubscriptionTransactionReportFailedError",
          code: "product_unknown",
        }),
      );
    });
  });
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

const signNotification = (
  signer: TestCertificateChain,
  { environment, signedTransactionInfo }: { environment: string; signedTransactionInfo: string },
) =>
  signAppStoreServerNotification(signer, {
    notificationType: "SUBSCRIBED",
    subtype: "INITIAL_BUY",
    notificationUUID: generateRecordId(),
    signedDate: Date.parse("2030-01-10T09:00:01Z"),
    data: { bundleId: env.APPLE_BUNDLE_ID, environment, signedTransactionInfo },
  });
