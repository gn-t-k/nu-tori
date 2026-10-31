import { beforeEach, describe, expect, test } from "vitest";
import {
  appStoreConnectListing,
  draftListingFields,
  type AppStoreConnectListing,
} from "./app-store-connect-listing";

describe("仮の文の欄", () => {
  let listing: AppStoreConnectListing;

  describe("文言がどれも本番の文のとき", () => {
    beforeEach(() => {
      listing = {
        ...appStoreConnectListing,
        subtitle: { ...appStoreConnectListing.subtitle, status: "final" },
        promotionalText: { ...appStoreConnectListing.promotionalText, status: "final" },
        description: { ...appStoreConnectListing.description, status: "final" },
        screenshots: appStoreConnectListing.screenshots.map((screenshot) => ({
          ...screenshot,
          headline: { ...screenshot.headline, status: "final" },
        })),
      };
    });

    test("挙げないこと", () => {
      expect(draftListingFields(listing)).toEqual([]);
    });
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
