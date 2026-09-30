import { eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/d1";
import { appleRefreshTokens } from "../apple-refresh-token-tables";

// 鍵は APPLE_REFRESH_TOKEN_KEYS に「版:base64 の鍵」をカンマで並べて置き、いちばん大きい版で暗号化する
export const createAppleRefreshTokenStore = (d1: D1Database, encryptionKeys: string) => {
  const db = drizzle(d1);
  const keys = parseEncryptionKeys(encryptionKeys);
  return {
    save: async (accountId: string, refreshToken: string): Promise<void> => {
      const { version, key } = await keys.current();
      const ciphertext = await encrypt(key, accountId, refreshToken);
      await db
        .insert(appleRefreshTokens)
        .values({ accountId, keyVersion: version, ciphertext })
        .onConflictDoUpdate({
          target: appleRefreshTokens.accountId,
          set: { keyVersion: version, ciphertext },
        });
    },
    find: async (accountId: string): Promise<string | undefined> => {
      const [row] = await db
        .select({
          keyVersion: appleRefreshTokens.keyVersion,
          ciphertext: appleRefreshTokens.ciphertext,
        })
        .from(appleRefreshTokens)
        .where(eq(appleRefreshTokens.accountId, accountId));
      if (row === undefined) {
        return undefined;
      }
      return decrypt(await keys.of(row.keyVersion), accountId, row.ciphertext);
    },
    delete: async (accountId: string): Promise<void> => {
      await db.delete(appleRefreshTokens).where(eq(appleRefreshTokens.accountId, accountId));
    },
  };
};

const parseEncryptionKeys = (encryptionKeys: string) => {
  const rawKeys = new Map(
    encryptionKeys.split(",").map((entry) => {
      const [version, base64] = entry.trim().split(":");
      if (version === undefined || base64 === undefined) {
        throw new Error("APPLE_REFRESH_TOKEN_KEYS は「版:base64 の鍵」をカンマで並べる");
      }
      return [Number(version), decodeBase64(base64)];
    }),
  );
  const importKey = (version: number) => {
    const rawKey = rawKeys.get(version);
    if (rawKey === undefined) {
      throw new Error(`APPLE_REFRESH_TOKEN_KEYS に版 ${version} の鍵が無い`);
    }
    return crypto.subtle.importKey("raw", rawKey, "AES-GCM", false, ["encrypt", "decrypt"]);
  };
  return {
    current: async () => {
      const version = Math.max(...rawKeys.keys());
      return { version, key: await importKey(version) };
    },
    of: importKey,
  };
};

// 暗号文をアカウント ID に結びつけ、ほかの行に移しても復号できないようにする
const encrypt = async (key: CryptoKey, accountId: string, plaintext: string): Promise<string> => {
  const iv = crypto.getRandomValues(new Uint8Array(ivLength));
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv, additionalData: new TextEncoder().encode(accountId) },
    key,
    new TextEncoder().encode(plaintext),
  );
  const joined = new Uint8Array(ivLength + encrypted.byteLength);
  joined.set(iv);
  joined.set(new Uint8Array(encrypted), ivLength);
  return encodeBase64(joined);
};

const decrypt = async (key: CryptoKey, accountId: string, ciphertext: string): Promise<string> => {
  const joined = decodeBase64(ciphertext);
  const decrypted = await crypto.subtle.decrypt(
    {
      name: "AES-GCM",
      iv: joined.subarray(0, ivLength),
      additionalData: new TextEncoder().encode(accountId),
    },
    key,
    joined.subarray(ivLength),
  );
  return new TextDecoder().decode(decrypted);
};

const ivLength = 12;

const encodeBase64 = (bytes: Uint8Array): string => btoa(String.fromCharCode(...bytes));

const decodeBase64 = (base64: string): Uint8Array<ArrayBuffer> =>
  Uint8Array.from(atob(base64), (character) => character.charCodeAt(0));
