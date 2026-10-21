import { beforeEach, describe, expect, test } from "vitest";
import type { FreeTrial } from "../compute-free-trial";
import { isWithinFreeTrial } from "./index";

describe("無料体験中か", () => {
  describe("最後の日が 2026-11-30 の無料体験があるとき", () => {
    let freeTrial: FreeTrial;
    beforeEach(() => {
      freeTrial = { type: "available", lastDay: "2026-11-30" };
    });

    test("数える日が最後の日なら、無料体験中であること", () => {
      expect(isWithinFreeTrial(freeTrial, "2026-11-30")).toBe(true);
    });

    test("数える日が最後の日の次の日なら、無料体験中でないこと", () => {
      expect(isWithinFreeTrial(freeTrial, "2026-12-01")).toBe(false);
    });
  });

  describe("作り直したアカウントのとき", () => {
    let freeTrial: FreeTrial;
    beforeEach(() => {
      freeTrial = { type: "used_by_earlier_account" };
    });

    test("どの日も無料体験中でないこと", () => {
      expect(isWithinFreeTrial(freeTrial, "2026-11-01")).toBe(false);
    });
  });
});
