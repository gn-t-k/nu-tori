import { beforeEach, describe, expect, test } from "vitest";
import { computeFreeTrial } from "./index";

describe("無料体験", () => {
  describe("課金を入れた日のあとにアカウントを作ったとき", () => {
    let account: Parameters<typeof computeFreeTrial>[0];
    beforeEach(() => {
      account = {
        startedOn: "2026-11-10",
        billingStartedOn: "2026-11-01",
        isExcludedByEarlierAccount: false,
      };
    });

    test("アカウントを作った日に 29 日足した日が最後の日であること", () => {
      expect(computeFreeTrial(account)).toEqual({ type: "available", lastDay: "2026-12-09" });
    });
  });

  describe("課金を入れた日より前にアカウントを作ったとき", () => {
    let account: Parameters<typeof computeFreeTrial>[0];
    beforeEach(() => {
      account = {
        startedOn: "2026-08-15",
        billingStartedOn: "2026-11-01",
        isExcludedByEarlierAccount: false,
      };
    });

    test("課金を入れた日に 29 日足した日が最後の日であること", () => {
      expect(computeFreeTrial(account)).toEqual({ type: "available", lastDay: "2026-11-30" });
    });
  });

  describe("課金を入れた日にアカウントを作ったとき", () => {
    let account: Parameters<typeof computeFreeTrial>[0];
    beforeEach(() => {
      account = {
        startedOn: "2026-11-01",
        billingStartedOn: "2026-11-01",
        isExcludedByEarlierAccount: false,
      };
    });

    test("その日に 29 日足した日が最後の日であること", () => {
      expect(computeFreeTrial(account)).toEqual({ type: "available", lastDay: "2026-11-30" });
    });
  });

  describe("年をまたぐとき", () => {
    let account: Parameters<typeof computeFreeTrial>[0];
    beforeEach(() => {
      account = {
        startedOn: "2026-12-20",
        billingStartedOn: "2026-11-01",
        isExcludedByEarlierAccount: false,
      };
    });

    test("次の年の日付が最後の日であること", () => {
      expect(computeFreeTrial(account)).toEqual({ type: "available", lastDay: "2027-01-18" });
    });
  });

  describe("うるう年の2月をまたぐとき", () => {
    let account: Parameters<typeof computeFreeTrial>[0];
    beforeEach(() => {
      account = {
        startedOn: "2028-02-10",
        billingStartedOn: "2026-11-01",
        isExcludedByEarlierAccount: false,
      };
    });

    test("2月29日を1日に数えた日が最後の日であること", () => {
      expect(computeFreeTrial(account)).toEqual({ type: "available", lastDay: "2028-03-10" });
    });
  });

  describe("作り直したアカウントのとき", () => {
    let account: Parameters<typeof computeFreeTrial>[0];
    beforeEach(() => {
      account = {
        startedOn: "2026-11-10",
        billingStartedOn: "2026-11-01",
        isExcludedByEarlierAccount: true,
      };
    });

    test("最後の日を持たず、前のアカウントで使ったことを返すこと", () => {
      expect(computeFreeTrial(account)).toEqual({ type: "used_by_earlier_account" });
    });
  });
});
