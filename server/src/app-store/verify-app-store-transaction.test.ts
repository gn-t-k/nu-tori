import { beforeEach, describe, expect, test } from "vitest";
import { createTestCertificateChain, signAppStoreTransaction } from "./testing";
import type { TestCertificateChain } from "./testing";
import { verifyAppStoreTransaction } from "./verify-app-store-transaction";

describe("App Store の取引の検証", () => {
  describe("鎖が差し込んだ根までつながるとき", () => {
    let chain: TestCertificateChain;
    let signedTransaction: string;
    beforeEach(async () => {
      chain = await createTestCertificateChain();
      signedTransaction = await signAppStoreTransaction(chain, {
        transactionId: "2000000000000005",
        originalTransactionId: "2000000000000001",
        bundleId: "app.nu-tori.test",
        productId: "app.nu_tori.subscription.yearly",
        purchaseDate: 1792454400000,
        expiresDate: 1823990400000,
        appAccountToken: "6f1c2a3b-4d5e-4f60-8a7b-9c0d1e2f3a4b",
        revocationDate: 1793000000000,
        environment: "Sandbox",
        transactionReason: "RENEWAL",
      });
    });

    test("仕様で使う項目だけを読むこと", async () => {
      expect(await verifyAppStoreTransaction(signedTransaction, chain.rootCertificate)).toBeSuccess(
        (transaction) => {
          expect(transaction).toStrictEqual({
            transactionId: "2000000000000005",
            originalTransactionId: "2000000000000001",
            bundleId: "app.nu-tori.test",
            productId: "app.nu_tori.subscription.yearly",
            purchaseDate: 1792454400000,
            expiresDate: 1823990400000,
            appAccountToken: "6f1c2a3b-4d5e-4f60-8a7b-9c0d1e2f3a4b",
            revocationDate: 1793000000000,
            environment: "Sandbox",
            transactionReason: "RENEWAL",
          });
        },
      );
    });
  });

  describe("アプリが購入者のトークンを渡さなかった取引のとき", () => {
    let chain: TestCertificateChain;
    let signedTransaction: string;
    beforeEach(async () => {
      chain = await createTestCertificateChain();
      signedTransaction = await signAppStoreTransaction(chain, {
        appAccountToken: undefined,
        revocationDate: undefined,
      });
    });

    test("購入者のトークンと取り消しの日時が無いこと", async () => {
      expect(await verifyAppStoreTransaction(signedTransaction, chain.rootCertificate)).toBeSuccess(
        (transaction) => {
          expect(transaction.appAccountToken).toBeUndefined();
          expect(transaction.revocationDate).toBeUndefined();
        },
      );
    });
  });

  describe("鎖の根が差し込んだ根と違うとき", () => {
    let otherRootCertificate: string;
    let signedTransaction: string;
    beforeEach(async () => {
      const [chain, otherChain] = await Promise.all([
        createTestCertificateChain(),
        createTestCertificateChain(),
      ]);
      otherRootCertificate = otherChain.rootCertificate;
      signedTransaction = await signAppStoreTransaction(chain);
    });

    test("AppStoreSignatureUnverifiedError で失敗すること", async () => {
      expect(await verifyAppStoreTransaction(signedTransaction, otherRootCertificate)).toBeFailure(
        (error) => {
          expect(error.name).toBe("AppStoreSignatureUnverifiedError");
        },
      );
    });
  });

  describe("中間の証明書が差し込んだ根で署名されていないとき", () => {
    let rootCertificate: string;
    let signedTransaction: string;
    beforeEach(async () => {
      const [chain, otherChain] = await Promise.all([
        createTestCertificateChain(),
        createTestCertificateChain(),
      ]);
      rootCertificate = chain.rootCertificate;
      // 根だけを差し込む根に差し替え、中間と署名の証明書はほかの鎖のまま
      signedTransaction = await signAppStoreTransaction({
        ...otherChain,
        x5c: [otherChain.x5c[0], otherChain.x5c[1], chain.rootCertificate],
      });
    });

    test("AppStoreSignatureUnverifiedError で失敗すること", async () => {
      expect(await verifyAppStoreTransaction(signedTransaction, rootCertificate)).toBeFailure(
        (error) => {
          expect(error.name).toBe("AppStoreSignatureUnverifiedError");
        },
      );
    });
  });

  describe("署名の証明書が中間の証明書で署名されていないとき", () => {
    let rootCertificate: string;
    let signedTransaction: string;
    beforeEach(async () => {
      const [chain, otherChain] = await Promise.all([
        createTestCertificateChain(),
        createTestCertificateChain(),
      ]);
      rootCertificate = chain.rootCertificate;
      signedTransaction = await signAppStoreTransaction({
        ...otherChain,
        x5c: [otherChain.x5c[0], chain.x5c[1], chain.x5c[2]],
      });
    });

    test("AppStoreSignatureUnverifiedError で失敗すること", async () => {
      expect(await verifyAppStoreTransaction(signedTransaction, rootCertificate)).toBeFailure(
        (error) => {
          expect(error.name).toBe("AppStoreSignatureUnverifiedError");
        },
      );
    });
  });

  describe("JWS が署名の証明書の鍵で署名されていないとき", () => {
    let rootCertificate: string;
    let signedTransaction: string;
    beforeEach(async () => {
      const [chain, otherChain] = await Promise.all([
        createTestCertificateChain(),
        createTestCertificateChain(),
      ]);
      rootCertificate = chain.rootCertificate;
      signedTransaction = await signAppStoreTransaction({
        ...chain,
        signingKey: otherChain.signingKey,
      });
    });

    test("AppStoreSignatureUnverifiedError で失敗すること", async () => {
      expect(await verifyAppStoreTransaction(signedTransaction, rootCertificate)).toBeFailure(
        (error) => {
          expect(error.name).toBe("AppStoreSignatureUnverifiedError");
        },
      );
    });
  });

  describe("中間の証明書に Apple の中間の印が無いとき", () => {
    let chain: TestCertificateChain;
    let signedTransaction: string;
    beforeEach(async () => {
      chain = await createTestCertificateChain({ intermediateHasAppleMarker: false });
      signedTransaction = await signAppStoreTransaction(chain);
    });

    test("AppStoreSignatureUnverifiedError で失敗すること", async () => {
      expect(await verifyAppStoreTransaction(signedTransaction, chain.rootCertificate)).toBeFailure(
        (error) => {
          expect(error.name).toBe("AppStoreSignatureUnverifiedError");
        },
      );
    });
  });

  describe("署名の証明書が署名の日時に有効期限を過ぎていたとき", () => {
    let chain: TestCertificateChain;
    let signedTransaction: string;
    beforeEach(async () => {
      chain = await createTestCertificateChain({
        leafValidity: {
          notBefore: new Date("2020-01-01T00:00:00Z"),
          notAfter: new Date("2026-10-19T23:59:59Z"),
        },
      });
      signedTransaction = await signAppStoreTransaction(chain, {
        signedDate: Date.parse("2026-10-20T00:00:00Z"),
      });
    });

    test("AppStoreSignatureUnverifiedError で失敗すること", async () => {
      expect(await verifyAppStoreTransaction(signedTransaction, chain.rootCertificate)).toBeFailure(
        (error) => {
          expect(error.name).toBe("AppStoreSignatureUnverifiedError");
        },
      );
    });
  });

  describe("ヘッダに鎖が無いとき", () => {
    let chain: TestCertificateChain;
    let signedTransaction: string;
    beforeEach(async () => {
      chain = await createTestCertificateChain();
      signedTransaction = await signAppStoreTransaction({ ...chain, x5c: [] });
    });

    test("AppStoreSignatureUnverifiedError で失敗すること", async () => {
      expect(await verifyAppStoreTransaction(signedTransaction, chain.rootCertificate)).toBeFailure(
        (error) => {
          expect(error.name).toBe("AppStoreSignatureUnverifiedError");
        },
      );
    });
  });
});
