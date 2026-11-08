// scripts/check-app-version の、版の番号の読み方と、審査に通った版との比べ方を確かめる
"use strict";

const assert = require("node:assert/strict");
const { describe, it } = require("node:test");
const { readMarketingVersion, findBlockingApprovedVersion, compareVersions } = require("./check-app-version");
const { ExpectedFailure } = require("./expected-failure.js");

const project = (...versions) => versions.map((version) => `\t\t\t\tMARKETING_VERSION = ${version};\n`).join("");

describe("MARKETING_VERSION を読む", () => {
  describe("すべての構成で同じとき", () => {
    it("その値を返すこと", () => {
      assert.equal(readMarketingVersion(project("1.0.1", "1.0.1")), "1.0.1");
    });
  });

  describe("構成で食い違うとき", () => {
    it("止まること", () => {
      assert.throws(() => readMarketingVersion(project("1.0.1", "1.0")), ExpectedFailure);
    });
  });

  describe("無いとき", () => {
    it("止まること", () => {
      assert.throws(() => readMarketingVersion(""), ExpectedFailure);
    });
  });

  describe("数の並びでないとき", () => {
    it("止まること", () => {
      assert.throws(() => readMarketingVersion(project("$(VERSION)")), ExpectedFailure);
    });
  });
});

describe("版の番号を比べる", () => {
  it("桁ごとに数として比べること", () => {
    assert.equal(compareVersions("1.10", "1.9"), 1);
  });

  it("欠けた桁を 0 とみなすこと", () => {
    assert.equal(compareVersions("1.0", "1.0.0"), 0);
  });
});

describe("審査に通った版と比べる", () => {
  describe("通った版と同じ番号のとき", () => {
    it("その通った版を返すこと", () => {
      const approved = { versionString: "1.0", appStoreState: "READY_FOR_SALE" };
      assert.deepEqual(findBlockingApprovedVersion("1.0", [approved]), approved);
    });
  });

  describe("通った版より大きいとき", () => {
    it("null を返すこと", () => {
      assert.equal(findBlockingApprovedVersion("1.0.1", [{ versionString: "1.0", appStoreState: "READY_FOR_SALE" }]), null);
    });
  });

  describe("同じ番号の版が審査に通る前のとき", () => {
    it("null を返すこと", () => {
      assert.equal(
        findBlockingApprovedVersion("1.1", [
          { versionString: "1.0", appStoreState: "READY_FOR_SALE" },
          { versionString: "1.1", appStoreState: "PREPARE_FOR_SUBMISSION" },
        ]),
        null,
      );
    });
  });

  describe("知らない状態の版のとき", () => {
    it("通った版とみなすこと", () => {
      const unknown = { versionString: "1.1", appStoreState: "SOME_NEW_STATE" };
      assert.deepEqual(findBlockingApprovedVersion("1.1", [unknown]), unknown);
    });
  });

  describe("通った版が無いとき", () => {
    it("null を返すこと", () => {
      assert.equal(findBlockingApprovedVersion("1.0", []), null);
    });
  });
});
