// scripts/app-store-connect の、役割 Sales and Reports の鍵を送る口と、segment を落とす先の絞りを確かめる
"use strict";

const assert = require("node:assert/strict");
const { describe, it } = require("node:test");
const { assertAnalyticsPath, toSegmentDownloadUrl } = require("./app-store-connect");
const { ExpectedFailure } = require("./expected-failure.js");

const apiUrl = (path) => new URL(path, "https://api.appstoreconnect.apple.com");

describe("Sales and Reports の鍵を送る口", () => {
  describe("Analytics Reports を読む口のとき", () => {
    it("申し込みの一覧を通すこと", () => {
      assert.doesNotThrow(() => assertAnalyticsPath(apiUrl("/v1/apps/6816842705/analyticsReportRequests")));
    });

    it("レポート・instance・segment の一覧と segment の詳細を通すこと", () => {
      assert.doesNotThrow(() =>
        assertAnalyticsPath(apiUrl("/v1/analyticsReportRequests/a1b2-c3/reports?filter[name]=App Store Discovery and Engagement Detailed")),
      );
      assert.doesNotThrow(() => assertAnalyticsPath(apiUrl("/v1/analyticsReports/r-1/instances?filter[granularity]=DAILY")));
      assert.doesNotThrow(() => assertAnalyticsPath(apiUrl("/v1/analyticsReportInstances/i-1/segments")));
      assert.doesNotThrow(() => assertAnalyticsPath(apiUrl("/v1/analyticsReportSegments/503110d4-0fa2-41c0-9d41-ab7c7dac683f")));
    });
  });

  describe("ほかの口のとき", () => {
    it("販売レポートを断ること", () => {
      assert.throws(() => assertAnalyticsPath(apiUrl("/v1/salesReports")), ExpectedFailure);
    });

    it("申し込みそのもの（Admin が POST する口）を断ること", () => {
      assert.throws(() => assertAnalyticsPath(apiUrl("/v1/analyticsReportRequests")), ExpectedFailure);
    });

    it("口の後ろにパスを足したものを断ること", () => {
      assert.throws(() => assertAnalyticsPath(apiUrl("/v1/analyticsReportInstances/i-1/segments/x")), ExpectedFailure);
    });
  });
});

describe("segment を落とす先", () => {
  describe("Apple の文書の例と同じ S3 の us-west-2 のとき", () => {
    it("署名つきの URL をそのまま返すこと", () => {
      const value = "https://asp-qa-us-west-2.s3.us-west-2.amazonaws.com/reports/1/0.csv.gz?X-Amz-Expires=300";
      assert.equal(toSegmentDownloadUrl(value).href, value);
    });
  });

  describe("ほかのホストのとき", () => {
    it("ほかの地域の S3 を断ること", () => {
      assert.throws(() => toSegmentDownloadUrl("https://bucket.s3.us-east-1.amazonaws.com/0.csv.gz"), ExpectedFailure);
    });

    it("ホストの名前の後ろを偽ったものを断ること", () => {
      assert.throws(() => toSegmentDownloadUrl("https://x.s3.us-west-2.amazonaws.com.example.com/0.csv.gz"), ExpectedFailure);
    });

    it("https でないものを断ること", () => {
      assert.throws(() => toSegmentDownloadUrl("http://bucket.s3.us-west-2.amazonaws.com/0.csv.gz"), ExpectedFailure);
    });
  });
});
