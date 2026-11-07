import type { AppStoreListing } from "./app-store-listing";

// LP の版ごとの App Store Connect のキャンペーンのリンク。ct で版ごとのダウンロード数を分けて見る
export const appStoreCampaignUrl = (listing: AppStoreListing, variant: string): string => {
  const url = new URL(`https://apps.apple.com/jp/app/apple-store/id${listing.appId}`);
  url.searchParams.set("pt", listing.providerToken);
  url.searchParams.set("ct", `lp-${variant}`);
  url.searchParams.set("mt", "8");
  return url.href;
};
