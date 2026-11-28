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
  describe("入った版をまだ審査に出していないとき", () => {
    let result;
    before(() => {
      result = plan({
        version: "1.2.1",
        mergedAt: "2026-11-28T04:59:21Z",
        mainVersion: "1.2.1",
        milestones: [
          { number: 1, title: "iOS 1.2.1", state: "open", closed_at: null },
          { number: 2, title: "iOS 1.3.0", state: "open", closed_at: null },
        ],
      });
    });

    it("その版に付け、次の版に置いたものも移すこと", () => {
      assert.deepEqual(result, { kind: "currentVersion" });
    });
  });

  describe("入った版のマイルストーンがまだ無いとき", () => {
    let result;
    before(() => {
      result = plan({
        version: "1.2.2",
        mergedAt: "2026-12-03T01:00:00Z",
        mainVersion: "1.2.2",
        milestones: [
          { number: 1, title: "iOS 1.2.1", state: "closed", closed_at: "2026-12-01T00:00:00Z" },
        ],
      });
    });

    it("その版に付け、次の版に置いたものも移すこと", () => {
      assert.deepEqual(result, { kind: "currentVersion" });
    });
  });

  describe("入った版を審査に出したあとに入ったとき", () => {
    let result;
    before(() => {
      result = plan({
        version: "1.2.1",
        mergedAt: "2026-12-02T00:00:00Z",
        mainVersion: "1.2.1",
        milestones: [
          { number: 1, title: "iOS 1.2.1", state: "closed", closed_at: "2026-12-01T00:00:00Z" },
          { number: 2, title: "iOS 1.3.0", state: "open", closed_at: null },
        ],
      });
    });

    it("次の版に置くこと", () => {
      assert.deepEqual(result, { kind: "pending" });
    });
  });

  describe("審査に出す前に入った PR を、出したあとに回したとき", () => {
    let result;
    before(() => {
      result = plan({
        version: "1.2.1",
        mergedAt: "2026-11-28T04:59:21Z",
        mainVersion: "1.2.1",
        milestones: [
          { number: 1, title: "iOS 1.2.1", state: "closed", closed_at: "2026-12-01T00:00:00Z" },
        ],
      });
    });

    it("入ったときの版に付け、次の版に置いたものは動かさないこと", () => {
      assert.deepEqual(result, { kind: "pastVersion" });
    });
  });

  describe("マイルストーンの無い前の版のころに入った PR を、main の版が進んでから回したとき", () => {
    let result;
    before(() => {
      result = plan({
        version: "1.2.0",
        mergedAt: "2026-11-20T00:00:00Z",
        mainVersion: "1.2.1",
        milestones: [
          { number: 1, title: "iOS 1.2.1", state: "open", closed_at: null },
          { number: 4, title: "iOS 次の版", state: "open", closed_at: null },
        ],
      });
    });

    it("入ったときの版に付け、次の版に置いたものは動かさないこと", () => {
      assert.deepEqual(result, { kind: "pastVersion" });
    });
  });

  describe("審査に出したあとに入った PR を、main の版が進んでから回したとき", () => {
    let result;
    before(() => {
      result = plan({
        version: "1.2.1",
        mergedAt: "2026-12-02T00:00:00Z",
        mainVersion: "1.2.2",
        milestones: [
          { number: 1, title: "iOS 1.2.1", state: "closed", closed_at: "2026-12-01T00:00:00Z" },
          { number: 3, title: "iOS 1.2.2", state: "open", closed_at: null },
        ],
      });
    });

    it("どの版に入ったかを決めないこと", () => {
      assert.deepEqual(result, { kind: "undecided" });
    });
  });
});
