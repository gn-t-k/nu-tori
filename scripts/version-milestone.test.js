// scripts/version-milestone の、PR に版を付けるかと、どのマイルストーンに付けるかの決め方を確かめる
"use strict";

const assert = require("node:assert/strict");
const { describe, it, before } = require("node:test");
const { reasonToSkip, plan } = require("./version-milestone");

const pullWith = (fields) => ({ merged_at: "2026-11-28T04:59:21Z", base: { ref: "main" }, milestone: null, ...fields });
const appPaths = ["ios/NuTori/Timeline/TimelineScreen.swift", "docs/agents/ios-mac.md"];

describe("PR に版を付けるか", () => {
  describe("main に入った PR が ios/ のコードを変えたとき", () => {
    let result;
    before(() => {
      result = reasonToSkip(pullWith({}), appPaths);
    });

    it("付けること", () => {
      assert.equal(result, null);
    });
  });

  describe("merge せずに閉じたとき", () => {
    let result;
    before(() => {
      result = reasonToSkip(pullWith({ merged_at: null }), appPaths);
    });

    it("付けないこと", () => {
      assert.equal(result, "main に入った PR でない");
    });
  });

  describe("main でないブランチに入ったとき", () => {
    let result;
    before(() => {
      result = reasonToSkip(pullWith({ base: { ref: "claude/spec-167-integration" } }), appPaths);
    });

    it("付けないこと", () => {
      assert.equal(result, "main に入った PR でない");
    });
  });

  describe("すでに版が付いているとき", () => {
    let result;
    before(() => {
      result = reasonToSkip(pullWith({ milestone: { title: "iOS 1.3.0" } }), appPaths);
    });

    it("付け替えないこと", () => {
      assert.equal(result, "すでに iOS 1.3.0 が付いている");
    });
  });

  describe("ios/ の外だけを変えたとき", () => {
    let result;
    before(() => {
      result = reasonToSkip(pullWith({}), ["server/src/index.ts", "site/src/pages/learn/index.ts"]);
    });

    it("付けないこと", () => {
      assert.equal(result, "ios/ を変えていない");
    });
  });

  describe("ios/ の文書だけを変えたとき", () => {
    let result;
    before(() => {
      result = reasonToSkip(pullWith({}), ["ios/AGENTS.md"]);
    });

    it("付けないこと", () => {
      assert.equal(result, "ios/ を変えていない");
    });
  });
});

describe("どのマイルストーンに付けるか", () => {
  describe("今の版のマイルストーンが開いているとき", () => {
    let result;
    before(() => {
      result = plan("1.2.1", [
        { number: 1, title: "iOS 1.2.1", state: "open" },
        { number: 2, title: "iOS 1.3.0", state: "open" },
      ]);
    });

    it("今の版に付け、次の版に置いたものも移すこと", () => {
      assert.deepEqual(result, { title: "iOS 1.2.1", movesPending: true });
    });
  });

  describe("今の版のマイルストーンがまだ無いとき", () => {
    let result;
    before(() => {
      result = plan("1.2.2", [{ number: 1, title: "iOS 1.2.1", state: "closed" }]);
    });

    it("今の版に付け、次の版に置いたものも移すこと", () => {
      assert.deepEqual(result, { title: "iOS 1.2.2", movesPending: true });
    });
  });

  describe("今の版のマイルストーンが閉じているとき", () => {
    let result;
    before(() => {
      result = plan("1.2.1", [
        { number: 1, title: "iOS 1.2.1", state: "closed" },
        { number: 2, title: "iOS 1.3.0", state: "open" },
      ]);
    });

    it("次の版に置くこと", () => {
      assert.deepEqual(result, { title: "iOS 次の版", movesPending: false });
    });
  });
});
