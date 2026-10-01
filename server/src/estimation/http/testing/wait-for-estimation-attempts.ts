import { vi } from "vitest";
import { readRows } from "../../../http/sync-routes/testing/read-rows";

// 待たずに動かしたアラームが、提供元を呼ぶ前の試みを count 個まで書くのを待つ
export const waitForEstimationAttempts = (accountId: string, count: number) =>
  vi.waitFor(async () => {
    const attempts = await readRows(accountId, "SELECT id FROM estimation_attempts");
    if (attempts.length < count) {
      throw new Error(`試みがまだ ${attempts.length} 個`);
    }
  });
