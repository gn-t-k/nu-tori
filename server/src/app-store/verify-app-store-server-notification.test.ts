import { beforeEach, describe, expect, test } from "vitest";
import {
  createTestCertificateChain,
  signAppStoreRenewalInfo,
  signAppStoreServerNotification,
  signAppStoreTransaction,
} from "./testing";
import type { TestCertificateChain } from "./testing";
import { verifyAppStoreServerNotification } from "./verify-app-store-server-notification";

describe("verifyAppStoreServerNotification", () => {
  describe("取引と更新の情報を持つ通知のとき", () => {
    let chain: TestCertificateChain;
    let signedPayload: string;
    beforeEach(async () => {
      chain = await createTestCertificateChain();
      signedPayload = await signAppStoreServerNotification(chain, {
        notificationType: "DID_FAIL_TO_RENEW",
        subtype: "GRACE_PERIOD",
        notificationUUID: "0b6c3e1a-2f4d-4c8e-9a7b-5d6e7f8a9b0c",
        signedDate: 1792454402000,
        data: {
          bundleId: "app.nu-tori.test",
          environment: "Sandbox",
          signedTransactionInfo: await signAppStoreTransaction(chain, {
            transactionId: "2000000000000005",
            originalTransactionId: "2000000000000001",
            bundleId: "app.nu-tori.test",
            productId: "app.nu-tori.subscription.monthly",
            purchaseDate: 1789776000000,
            expiresDate: 1792454400000,
            appAccountToken: undefined,
            revocationDate: undefined,
            environment: "Sandbox",
            transactionReason: "RENEWAL",
          }),
          signedRenewalInfo: await signAppStoreRenewalInfo(chain, {
            gracePeriodExpiresDate: 1793836800000,
          }),
        },
      });
    });

    test("通知と、中の取引と更新の情報の、仕様で使う項目だけを読むこと", async () => {
      expect(
        await verifyAppStoreServerNotification(signedPayload, chain.rootCertificate),
      ).toBeSuccess((notification) => {
        expect(notification).toStrictEqual({
          notificationUUID: "0b6c3e1a-2f4d-4c8e-9a7b-5d6e7f8a9b0c",
          notificationType: "DID_FAIL_TO_RENEW",
          subtype: "GRACE_PERIOD",
          signedDate: 1792454402000,
          data: {
            bundleId: "app.nu-tori.test",
            environment: "Sandbox",
            transaction: {
              transactionId: "2000000000000005",
              originalTransactionId: "2000000000000001",
              bundleId: "app.nu-tori.test",
              productId: "app.nu-tori.subscription.monthly",
              purchaseDate: 1789776000000,
              expiresDate: 1792454400000,
              appAccountToken: undefined,
              revocationDate: undefined,
              environment: "Sandbox",
              transactionReason: "RENEWAL",
            },
            renewalInfo: { gracePeriodExpiresDate: 1793836800000 },
          },
        });
      });
    });
  });

  describe("取引も更新の情報も持たない通知のとき", () => {
    let chain: TestCertificateChain;
    let signedPayload: string;
    beforeEach(async () => {
      chain = await createTestCertificateChain();
      signedPayload = await signAppStoreServerNotification(chain, {
        notificationType: "TEST",
        subtype: undefined,
        data: { bundleId: "app.nu-tori.test", environment: "Production" },
      });
    });

    test("subtype と取引と更新の情報が無いこと", async () => {
      expect(
        await verifyAppStoreServerNotification(signedPayload, chain.rootCertificate),
      ).toBeSuccess((notification) => {
        expect(notification.subtype).toBeUndefined();
        expect(notification.data?.transaction).toBeUndefined();
        expect(notification.data?.renewalInfo).toBeUndefined();
      });
    });
  });

  describe("中の取引が差し込んだ根につながらない鎖で署名されているとき", () => {
    let chain: TestCertificateChain;
    let signedPayload: string;
    beforeEach(async () => {
      const otherChain = await createTestCertificateChain();
      chain = await createTestCertificateChain();
      signedPayload = await signAppStoreServerNotification(chain, {
        data: {
          bundleId: "app.nu-tori.test",
          environment: "Production",
          signedTransactionInfo: await signAppStoreTransaction(otherChain),
        },
      });
    });

    test("AppStoreSignatureUnverifiedError で失敗すること", async () => {
      expect(
        await verifyAppStoreServerNotification(signedPayload, chain.rootCertificate),
      ).toBeFailure((error) => {
        expect(error.name).toBe("AppStoreSignatureUnverifiedError");
      });
    });
  });

  describe("中の更新の情報が差し込んだ根につながらない鎖で署名されているとき", () => {
    let chain: TestCertificateChain;
    let signedPayload: string;
    beforeEach(async () => {
      const otherChain = await createTestCertificateChain();
      chain = await createTestCertificateChain();
      signedPayload = await signAppStoreServerNotification(chain, {
        data: {
          bundleId: "app.nu-tori.test",
          environment: "Production",
          signedTransactionInfo: await signAppStoreTransaction(chain),
          signedRenewalInfo: await signAppStoreRenewalInfo(otherChain),
        },
      });
    });

    test("AppStoreSignatureUnverifiedError で失敗すること", async () => {
      expect(
        await verifyAppStoreServerNotification(signedPayload, chain.rootCertificate),
      ).toBeFailure((error) => {
        expect(error.name).toBe("AppStoreSignatureUnverifiedError");
      });
    });
  });

  describe("本文が差し込んだ根につながらない鎖で署名されているとき", () => {
    let rootCertificate: string;
    let signedPayload: string;
    beforeEach(async () => {
      const [chain, otherChain] = await Promise.all([
        createTestCertificateChain(),
        createTestCertificateChain(),
      ]);
      rootCertificate = chain.rootCertificate;
      signedPayload = await signAppStoreServerNotification(otherChain);
    });

    test("AppStoreSignatureUnverifiedError で失敗すること", async () => {
      expect(await verifyAppStoreServerNotification(signedPayload, rootCertificate)).toBeFailure(
        (error) => {
          expect(error.name).toBe("AppStoreSignatureUnverifiedError");
        },
      );
    });
  });
});
