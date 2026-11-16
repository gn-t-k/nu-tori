import { beforeEach, describe, expect, test, vi } from "vitest";
import { ensureSyncWriteAllowance } from "./ensure-sync-write-allowance";

const now = new Date("2026-06-02T12:00:00Z");

describe("同期の書き込みの数の上限", () => {
  describe("直近 24 時間の書き込みが 29,999 件のとき", () => {
    let countWriteReceiptsAfter: ReturnType<typeof vi.fn<(receivedAfter: Date) => number>>;
    beforeEach(() => {
      countWriteReceiptsAfter = vi.fn<(receivedAfter: Date) => number>().mockReturnValue(29_999);
    });

    test("受けること", () => {
      expect(ensureSyncWriteAllowance({ countWriteReceiptsAfter }, now)).toBeSuccess();
    });

    test("24 時間前よりあとの書き込みを数えること", () => {
      ensureSyncWriteAllowance({ countWriteReceiptsAfter }, now);
      expect(countWriteReceiptsAfter).toHaveBeenCalledWith(new Date("2026-06-01T12:00:00Z"));
    });
  });

  describe("直近 24 時間の書き込みが 30,000 件のとき", () => {
    test("SyncWriteAllowanceExhaustedError で断ること", () => {
      expect(ensureSyncWriteAllowance({ countWriteReceiptsAfter: () => 30_000 }, now)).toBeFailure(
        (error) => {
          expect(error.name).toBe("SyncWriteAllowanceExhaustedError");
        },
      );
    });
  });
});
