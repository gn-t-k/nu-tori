// scripts/production-alerts の、閉じた Issue の Sentry の課題を解決にするかの決め方を確かめる
"use strict";

const assert = require("node:assert/strict");
const { describe, it, before } = require("node:test");
const { isResolvable, planResolution } = require("./production-alerts");

const now = new Date("2026-11-10T00:00:00Z");
const issueWith = (fields) => ({ state: "closed", state_reason: "completed", closed_at: "2026-11-09T00:00:00Z", ...fields });

describe("閉じた Issue を解決の対象にするか", () => {
  describe("完了で閉じたとき", () => {
    let result;
    before(() => {
      result = isResolvable(issueWith({}), now);
    });

    it("対象にすること", () => {
      assert.equal(result, true);
    });
  });

  describe("予定なしで閉じたとき", () => {
    let result;
    before(() => {
      result = isResolvable(issueWith({ state_reason: "not_planned" }), now);
    });

    it("対象にしないこと", () => {
      assert.equal(result, false);
    });
  });

  describe("開いているとき", () => {
    let result;
    before(() => {
      result = isResolvable(issueWith({ state: "open", state_reason: null, closed_at: null }), now);
    });

    it("対象にしないこと", () => {
      assert.equal(result, false);
    });
  });

  describe("閉じてから7日を過ぎたとき", () => {
    let result;
    before(() => {
      result = isResolvable(issueWith({ closed_at: "2026-11-02T23:59:59Z" }), now);
    });

    it("対象にしないこと", () => {
      assert.equal(result, false);
    });
  });
});

describe("Sentry の課題をどうするか決める", () => {
  describe("iOS の未解決の課題のとき", () => {
    let result;
    before(() => {
      result = planResolution({ status: "unresolved", project: { slug: "nu-tori-ios" } });
    });

    it("次の版で解決にすること", () => {
      assert.deepEqual(result, { action: "resolve", in: "@next", label: "次の版で解決" });
    });
  });

  describe("サーバーの未解決の課題のとき", () => {
    let result;
    before(() => {
      result = planResolution({ status: "unresolved", project: { slug: "nu-tori-server" } });
    });

    it("すぐ解決にすること", () => {
      assert.deepEqual(result, { action: "resolve", label: "すぐ解決" });
    });
  });

  describe("知らないプロジェクトの未解決の課題のとき", () => {
    let result;
    before(() => {
      result = planResolution({ status: "unresolved", project: { slug: "nu-tori-web" } });
    });

    it("解決の種類が決まっていないと返すこと", () => {
      assert.equal(result.action, "undecided");
    });
  });

  describe("すでに解決済みのとき", () => {
    let result;
    before(() => {
      result = planResolution({ status: "resolved", project: { slug: "nu-tori-ios" } });
    });

    it("印だけを付けること", () => {
      assert.equal(result.action, "mark");
    });
  });

  describe("アーカイブ済みのとき", () => {
    let result;
    before(() => {
      result = planResolution({ status: "ignored", project: { slug: "nu-tori-ios" } });
    });

    it("何もしないこと", () => {
      assert.equal(result.action, "skip");
    });
  });

  describe("課題が見つからないとき", () => {
    let result;
    before(() => {
      result = planResolution(undefined);
    });

    it("何もしないこと", () => {
      assert.equal(result.action, "skip");
    });
  });
});
