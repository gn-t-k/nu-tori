import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { createAppleRefreshTokenStore } from "./index";
import { createEncryptionKey } from "./testing/create-encryption-key";

describe("Apple の refresh token の置き場", () => {
  describe("保存したとき", () => {
    let accountId: string;
    let store: ReturnType<typeof createAppleRefreshTokenStore>;
    beforeEach(async () => {
      accountId = crypto.randomUUID();
      store = createAppleRefreshTokenStore(env.DB, `1:${createEncryptionKey(1)}`);
      await store.save(accountId, "apple-refresh-token");
    });

    test("保存した refresh token を読み出せること", async () => {
      await expect(store.find(accountId)).resolves.toBe("apple-refresh-token");
    });

    test("D1 には暗号化して入れること", async () => {
      const row = await env.DB.prepare(
        "SELECT ciphertext FROM apple_refresh_tokens WHERE account_id = ?",
      )
        .bind(accountId)
        .first<{ ciphertext: string }>();
      expect(row?.ciphertext).not.toContain("apple-refresh-token");
    });
  });

  describe("鍵を新しい版に入れ替えたとき", () => {
    let savedAccountId: string;
    let newAccountId: string;
    let store: ReturnType<typeof createAppleRefreshTokenStore>;
    let storeWithOnlyNewKey: ReturnType<typeof createAppleRefreshTokenStore>;
    let newRefreshToken: string;
    beforeEach(async () => {
      newRefreshToken = "new-apple-refresh-token";
      savedAccountId = crypto.randomUUID();
      newAccountId = crypto.randomUUID();
      const previousKey = createEncryptionKey(1);
      const newKey = createEncryptionKey(2);
      await createAppleRefreshTokenStore(env.DB, `1:${previousKey}`).save(
        savedAccountId,
        "apple-refresh-token",
      );
      store = createAppleRefreshTokenStore(env.DB, `2:${newKey},1:${previousKey}`);
      storeWithOnlyNewKey = createAppleRefreshTokenStore(env.DB, `2:${newKey}`);
    });

    test("前の版の鍵で保存したものを読み出せること", async () => {
      await expect(store.find(savedAccountId)).resolves.toBe("apple-refresh-token");
    });

    test("新しく保存するものは新しい版の鍵で暗号化すること", async () => {
      await store.save(newAccountId, newRefreshToken);
      await expect(storeWithOnlyNewKey.find(newAccountId)).resolves.toBe(newRefreshToken);
    });
  });

  describe("保存していないとき", () => {
    let accountId: string;
    let store: ReturnType<typeof createAppleRefreshTokenStore>;
    beforeEach(() => {
      accountId = crypto.randomUUID();
      store = createAppleRefreshTokenStore(env.DB, `1:${createEncryptionKey(1)}`);
    });

    test("無いことを返すこと", async () => {
      await expect(store.find(accountId)).resolves.toBeUndefined();
    });
  });
});
