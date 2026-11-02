import { beforeEach, describe, expect, test } from "vitest";
import {
  appStoreConnectListing,
  draftListingFields,
  type AppStoreConnectListing,
} from "./app-store-connect-listing";

describe("仮の文の欄", () => {
  let listing: AppStoreConnectListing;

  // 本番の文は #862 で書いた。仮の文に戻すと wizard が App Store Connect に入れる段を始めない
  test("今の掲載情報では挙げないこと", () => {
    expect(draftListingFields(appStoreConnectListing)).toEqual([]);
  });

  describe("説明文と2枚目の見出しが仮の文のとき", () => {
    beforeEach(() => {
      listing = {
        ...appStoreConnectListing,
        subtitle: { ...appStoreConnectListing.subtitle, status: "final" },
        promotionalText: { ...appStoreConnectListing.promotionalText, status: "final" },
        description: { ...appStoreConnectListing.description, status: "draft" },
        screenshots: appStoreConnectListing.screenshots.map((screenshot) => ({
          ...screenshot,
          headline: {
            ...screenshot.headline,
            status: screenshot.name === "02" ? "draft" : "final",
          },
        })),
      };
    });

    test("その欄を挙げること", () => {
      expect(draftListingFields(listing)).toEqual(["description", "screenshots.02.headline"]);
    });
  });
});
