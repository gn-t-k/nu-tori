import { env } from "cloudflare:workers";

// テストの鍵（vitest.config.ts の APPLE_SUB_HASH_KEYS）の版を選び、Apple の sub を HMAC-SHA256 の16進にする
export const hashAppleSub = async (appleSub: string, keyVersion: number): Promise<string> => {
  const entry = env.APPLE_SUB_HASH_KEYS.split(",")
    .map((pair) => pair.split(":"))
    .find(([version]) => Number(version) === keyVersion);
  if (entry?.[1] === undefined) {
    throw new Error(`テストの鍵に版 ${keyVersion} が無い`);
  }
  const key = await crypto.subtle.importKey(
    "raw",
    Uint8Array.from(atob(entry[1]), (character) => character.charCodeAt(0)),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(appleSub));
  return Array.from(new Uint8Array(signature), (byte) => byte.toString(16).padStart(2, "0")).join(
    "",
  );
};
