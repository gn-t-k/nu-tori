import { inArray } from "drizzle-orm";
import { drizzle } from "drizzle-orm/d1";
import { findAppleSub } from "../../auth/find-apple-sub";
import { parseVersionedKeys } from "../../auth/parse-versioned-keys";
import { generateRecordId } from "../../domain/record-id";
import { subscriptionD1Tables } from "./subscription-d1-tables";

const { freeTrialUsages } = subscriptionD1Tables;

// 無料体験を使った Apple ID。退会のあとも、Apple の sub を元に戻せない鍵付きハッシュ（HMAC-SHA256）にして残す。
// 鍵は APPLE_SUB_HASH_KEYS に「版:base64 の鍵」をカンマで並べて置き、今の版で書き、残っている版の全部で引く。
// 鍵を替えても古い版の行は書き直せない（元の sub が無い）ので、古い版の鍵は消さない。
// どちらの口もアカウント ID を受け、そのアカウントの Apple の sub で書く・引く
export const createFreeTrialUsageStore = (d1: D1Database, hashKeys: string) => {
  const db = drizzle(d1);
  const keys = parseVersionedKeys("APPLE_SUB_HASH_KEYS", hashKeys);
  const hash = async (version: number, appleSub: string): Promise<string> => {
    const key = await crypto.subtle.importKey(
      "raw",
      keys.rawKeyOf(version),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );
    const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(appleSub));
    return Array.from(new Uint8Array(signature), (byte) => byte.toString(16).padStart(2, "0")).join(
      "",
    );
  };
  return {
    // 同じハッシュがあれば何もしない。確かめのジョブのアカウントは Apple の sub を持たないので、何も書かない
    record: async (accountId: string): Promise<void> => {
      const appleSub = await findAppleSub(d1, accountId);
      if (appleSub === undefined) {
        return;
      }
      await db
        .insert(freeTrialUsages)
        .values({
          id: generateRecordId(),
          appleSubHash: await hash(keys.currentVersion, appleSub),
          keyVersion: keys.currentVersion,
        })
        .onConflictDoNothing({ target: freeTrialUsages.appleSubHash });
    },
    // Apple でサインインしたアカウントにだけ使う
    isUsed: async (accountId: string): Promise<boolean> => {
      const appleSub = await findAppleSub(d1, accountId);
      if (appleSub === undefined) {
        throw new Error("Apple でサインインしたアカウントに Apple の sub が無い");
      }
      const hashes = await Promise.all(keys.versions.map((version) => hash(version, appleSub)));
      const [usage] = await db
        .select({ id: freeTrialUsages.id })
        .from(freeTrialUsages)
        .where(inArray(freeTrialUsages.appleSubHash, hashes))
        .limit(1);
      return usage !== undefined;
    },
  };
};
