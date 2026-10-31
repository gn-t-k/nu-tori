import { beforeEach, describe, expect, test } from "vitest";
import {
  appStoreConnectListing,
  medicalDisclaimer,
  type AppStoreConnectListing,
} from "./app-store-connect-listing";
import { listingRuleViolations } from "./listing-rule-violations";
import { examplePriceText } from "./testing/example-price-text";

describe("掲載情報の決まり", () => {
  describe("今の掲載情報", () => {
    test("決まりに外れないこと", () => {
      expect(listingRuleViolations(appStoreConnectListing)).toEqual([]);
    });
  });

  describe("字数と大きさ", () => {
    let listing: AppStoreConnectListing;

    describe("名前が30字を超えるとき", () => {
      beforeEach(() => {
        listing = { ...appStoreConnectListing, name: "n".repeat(31) };
      });

      test("名前が長すぎると挙げること", () => {
        expect(listingRuleViolations(listing)).toEqual(["name-too-long"]);
      });
    });

    describe("名前がちょうど30字のとき", () => {
      beforeEach(() => {
        listing = { ...appStoreConnectListing, name: "n".repeat(30) };
      });

      test("名前を挙げないこと", () => {
        expect(listingRuleViolations(listing)).toEqual([]);
      });
    });

    describe("サブタイトルが30字を超えるとき", () => {
      beforeEach(() => {
        listing = {
          ...appStoreConnectListing,
          subtitle: { status: "draft", text: "s".repeat(31) },
        };
      });

      test("サブタイトルが長すぎると挙げること", () => {
        expect(listingRuleViolations(listing)).toEqual(["subtitle-too-long"]);
      });
    });

    describe("プロモーション用テキストが170字を超えるとき", () => {
      beforeEach(() => {
        listing = {
          ...appStoreConnectListing,
          promotionalText: { status: "draft", text: "p".repeat(171) },
        };
      });

      test("プロモーション用テキストが長すぎると挙げること", () => {
        expect(listingRuleViolations(listing)).toEqual(["promotional-text-too-long"]);
      });
    });

    describe("説明文が4000字を超えるとき", () => {
      beforeEach(() => {
        listing = {
          ...appStoreConnectListing,
          description: {
            status: "draft",
            text: `${appStoreConnectListing.description.text}${"d".repeat(4000)}`,
          },
        };
      });

      test("説明文が長すぎると挙げること", () => {
        expect(listingRuleViolations(listing)).toEqual(["description-too-long"]);
      });
    });

    // 上限は Apple の文書で 100 バイトと 100 字が食い違うので、狭いバイトで数える
    describe("キーワード欄が100バイトを超えるとき", () => {
      beforeEach(() => {
        listing = {
          ...appStoreConnectListing,
          keywords: `${appStoreConnectListing.keywords},${"x".repeat(5)}`,
        };
      });

      test("キーワード欄が長すぎると挙げること", () => {
        expect(listingRuleViolations(listing)).toEqual(["keywords-too-long"]);
      });
    });
  });

  describe("キーワード欄の語", () => {
    let listing: AppStoreConnectListing;

    describe("名前にある語を入れたとき", () => {
      beforeEach(() => {
        listing = { ...appStoreConnectListing, keywords: "NU-TORI,PFC" };
      });

      test("名前かサブタイトルと重なると挙げること", () => {
        expect(listingRuleViolations(listing)).toEqual(["keyword-in-name-or-subtitle"]);
      });
    });

    describe("サブタイトルにある語を入れたとき", () => {
      beforeEach(() => {
        listing = {
          ...appStoreConnectListing,
          subtitle: { status: "draft", text: "Track PFC" },
          keywords: "PFC",
        };
      });

      test("名前かサブタイトルと重なると挙げること", () => {
        expect(listingRuleViolations(listing)).toEqual(["keyword-in-name-or-subtitle"]);
      });
    });

    describe("同じ語を2回入れたとき", () => {
      beforeEach(() => {
        listing = { ...appStoreConnectListing, keywords: "PFC,AI,pfc" };
      });

      test("語が重なると挙げること", () => {
        expect(listingRuleViolations(listing)).toEqual(["duplicate-keyword"]);
      });
    });
  });

  describe("金額", () => {
    let listing: AppStoreConnectListing;

    describe("説明文に金額があるとき", () => {
      beforeEach(() => {
        listing = {
          ...appStoreConnectListing,
          description: {
            status: "draft",
            text: `${appStoreConnectListing.description.text}${examplePriceText}`,
          },
        };
      });

      test("説明文に金額があると挙げること", () => {
        expect(listingRuleViolations(listing)).toEqual(["price-in-description"]);
      });
    });

    describe("スクリーンショットの見出しに金額があるとき", () => {
      beforeEach(() => {
        listing = {
          ...appStoreConnectListing,
          screenshots: appStoreConnectListing.screenshots.map((screenshot, index) =>
            index === 4
              ? { ...screenshot, headline: { status: "draft", text: examplePriceText } }
              : screenshot,
          ),
        };
      });

      test("見出しに金額があると挙げること", () => {
        expect(listingRuleViolations(listing)).toEqual(["price-in-screenshot-headline"]);
      });
    });
  });

  describe("説明文に要るもの", () => {
    let listing: AppStoreConnectListing;

    describe("利用規約の URL が無いとき", () => {
      beforeEach(() => {
        listing = {
          ...appStoreConnectListing,
          description: {
            status: "draft",
            text: appStoreConnectListing.description.text.replaceAll(
              appStoreConnectListing.urls.terms,
              "",
            ),
          },
        };
      });

      test("利用規約の URL が無いと挙げること", () => {
        expect(listingRuleViolations(listing)).toEqual(["terms-url-missing"]);
      });
    });

    describe("プライバシーポリシーの URL が無いとき", () => {
      beforeEach(() => {
        listing = {
          ...appStoreConnectListing,
          description: {
            status: "draft",
            text: appStoreConnectListing.description.text.replaceAll(
              appStoreConnectListing.urls.privacyPolicy,
              "",
            ),
          },
        };
      });

      test("プライバシーポリシーの URL が無いと挙げること", () => {
        expect(listingRuleViolations(listing)).toEqual(["privacy-policy-url-missing"]);
      });
    });

    describe("医療の一文が無いとき", () => {
      beforeEach(() => {
        listing = {
          ...appStoreConnectListing,
          description: {
            status: "draft",
            text: appStoreConnectListing.description.text.replaceAll(medicalDisclaimer, ""),
          },
        };
      });

      test("医療の一文が無いと挙げること", () => {
        expect(listingRuleViolations(listing)).toEqual(["medical-disclaimer-missing"]);
      });
    });
  });
});
