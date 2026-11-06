// scripts/app-store-connect の、役割 Sales and Reports の鍵を送る口と、segment を落とす先の絞りを確かめる
"use strict";

const assert = require("node:assert/strict");
const { describe, it, before } = require("node:test");
const { assertAnalyticsPath, toSegmentDownloadUrl } = require("./app-store-connect");
const { ExpectedFailure } = require("./expected-failure.js");

const apiUrl = (path) => new URL(path, "https://api.appstoreconnect.apple.com");

describe("Sales and Reports の鍵を送る口", () => {
  describe("申し込みの一覧のとき", () => {
    let url;
    before(() => {
      url = apiUrl("/v1/apps/6816842705/analyticsReportRequests");
    });

    it("通すこと", () => {
      assert.doesNotThrow(() => assertAnalyticsPath(url));
    });
  });

  describe("レポートの一覧のとき", () => {
    let url;
    before(() => {
      url = apiUrl("/v1/analyticsReportRequests/a1b2-c3/reports?filter[name]=App Store Discovery and Engagement Detailed");
    });

    it("通すこと", () => {
      assert.doesNotThrow(() => assertAnalyticsPath(url));
    });
  });

  describe("instance の一覧のとき", () => {
    let url;
    before(() => {
      url = apiUrl("/v1/analyticsReports/r-1/instances?filter[granularity]=DAILY");
    });

    it("通すこと", () => {
      assert.doesNotThrow(() => assertAnalyticsPath(url));
    });
  });

  describe("segment の一覧のとき", () => {
    let url;
    before(() => {
      url = apiUrl("/v1/analyticsReportInstances/i-1/segments");
    });

    it("通すこと", () => {
      assert.doesNotThrow(() => assertAnalyticsPath(url));
    });
  });

  describe("segment の詳細のとき", () => {
    let url;
    before(() => {
      url = apiUrl("/v1/analyticsReportSegments/503110d4-0fa2-41c0-9d41-ab7c7dac683f");
    });

    it("通すこと", () => {
      assert.doesNotThrow(() => assertAnalyticsPath(url));
    });
  });

  describe("販売レポートのとき", () => {
    let url;
    before(() => {
      url = apiUrl("/v1/salesReports");
    });

    it("断ること", () => {
      assert.throws(() => assertAnalyticsPath(url), ExpectedFailure);
    });
  });

  describe("申し込みそのもの（Admin が POST する口）のとき", () => {
    let url;
    before(() => {
      url = apiUrl("/v1/analyticsReportRequests");
    });

    it("断ること", () => {
      assert.throws(() => assertAnalyticsPath(url), ExpectedFailure);
    });
  });

  describe("通す口の後ろにパスを足したとき", () => {
    let url;
    before(() => {
      url = apiUrl("/v1/analyticsReportInstances/i-1/segments/x");
    });

    it("断ること", () => {
      assert.throws(() => assertAnalyticsPath(url), ExpectedFailure);
    });
  });
});

describe("segment を落とす先", () => {
  describe("Apple の文書の例と同じ S3 の us-west-2 のとき", () => {
    let value;
    before(() => {
      value = "https://asp-qa-us-west-2.s3.us-west-2.amazonaws.com/reports/1/0.csv.gz?X-Amz-Expires=300";
    });

    it("署名つきの URL をそのまま返すこと", () => {
      assert.equal(toSegmentDownloadUrl(value).href, value);
    });
  });

  describe("ほかの地域の S3 のとき", () => {
    let value;
    before(() => {
      value = "https://bucket.s3.us-east-1.amazonaws.com/0.csv.gz";
    });

    it("断ること", () => {
      assert.throws(() => toSegmentDownloadUrl(value), ExpectedFailure);
    });
  });

  describe("ホストの名前の後ろを偽ったとき", () => {
    let value;
    before(() => {
      value = "https://x.s3.us-west-2.amazonaws.com.example.com/0.csv.gz";
    });

    it("断ること", () => {
      assert.throws(() => toSegmentDownloadUrl(value), ExpectedFailure);
    });
  });

  describe("https でないとき", () => {
    let value;
    before(() => {
      value = "http://bucket.s3.us-west-2.amazonaws.com/0.csv.gz";
    });

    it("断ること", () => {
      assert.throws(() => toSegmentDownloadUrl(value), ExpectedFailure);
    });
  });
});
