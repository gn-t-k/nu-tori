// scripts/check-app-version の、版の番号の読み方と、審査に通った版との比べ方を確かめる
"use strict";

const assert = require("node:assert/strict");
const { describe, it, before } = require("node:test");
const { readMarketingVersion, findBlockingApprovedVersion, compareVersions } = require("./check-app-version");
const { ExpectedFailure } = require("./expected-failure.js");

const project = (...versions) => versions.map((version) => `\t\t\t\tMARKETING_VERSION = ${version};\n`).join("");

describe("MARKETING_VERSION を読む", () => {
  describe("すべての構成で同じとき", () => {
    let input;
    before(() => {
      input = project("1.0.1", "1.0.1");
    });

    it("その値を返すこと", () => {
      assert.equal(readMarketingVersion(input), "1.0.1");
    });
  });

  describe("構成で食い違うとき", () => {
    let input;
    before(() => {
      input = project("1.0.1", "1.0");
    });

    it("止まること", () => {
      assert.throws(() => readMarketingVersion(input), ExpectedFailure);
    });
  });

  describe("無いとき", () => {
    let input;
    before(() => {
      input = "";
    });

    it("止まること", () => {
      assert.throws(() => readMarketingVersion(input), ExpectedFailure);
    });
  });

  describe("数の並びでないとき", () => {
    let input;
    before(() => {
      input = project("$(VERSION)");
    });

    it("止まること", () => {
      assert.throws(() => readMarketingVersion(input), ExpectedFailure);
    });
  });
});

describe("版の番号を比べる", () => {
  describe("桁の数字の数が違うとき", () => {
    let result;
    before(() => {
      result = compareVersions("1.10", "1.9");
    });

    it("数として比べること", () => {
      assert.equal(result, 1);
    });
  });

  describe("桁の数が違うとき", () => {
    let result;
    before(() => {
      result = compareVersions("1.0", "1.0.0");
    });

    it("欠けた桁を 0 とみなすこと", () => {
      assert.equal(result, 0);
    });
  });
});

describe("審査に通った版と比べる", () => {
  describe("通った版と同じ番号のとき", () => {
    let approved;
    let result;
    before(() => {
      approved = { versionString: "1.0", appStoreState: "READY_FOR_SALE" };
      result = findBlockingApprovedVersion("1.0", [approved]);
    });

    it("その通った版を返すこと", () => {
      assert.deepEqual(result, approved);
    });
  });

  describe("通った版より大きいとき", () => {
    let result;
    before(() => {
      result = findBlockingApprovedVersion("1.0.1", [{ versionString: "1.0", appStoreState: "READY_FOR_SALE" }]);
    });

    it("null を返すこと", () => {
      assert.equal(result, null);
    });
  });

  describe("同じ番号の版が審査に通る前のとき", () => {
    let result;
    before(() => {
      result = findBlockingApprovedVersion("1.1", [
        { versionString: "1.0", appStoreState: "READY_FOR_SALE" },
        { versionString: "1.1", appStoreState: "PREPARE_FOR_SUBMISSION" },
      ]);
    });

    it("null を返すこと", () => {
      assert.equal(result, null);
    });
  });

  describe("知らない状態の版のとき", () => {
    let unknown;
    let result;
    before(() => {
      unknown = { versionString: "1.1", appStoreState: "SOME_NEW_STATE" };
      result = findBlockingApprovedVersion("1.1", [unknown]);
    });

    it("通った版とみなすこと", () => {
      assert.deepEqual(result, unknown);
    });
  });

  describe("通った版が無いとき", () => {
    let result;
    before(() => {
      result = findBlockingApprovedVersion("1.0", []);
    });

    it("null を返すこと", () => {
      assert.equal(result, null);
    });
  });
});
