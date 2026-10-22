import { AppStoreBadge } from "../app-store-badge";
import { appStoreListing } from "../app-store-listing";
import { createLandingVariantPage } from "../create-landing-variant-page";
import { createSiteApp } from "../create-site-app";
import { sitePages } from "../site-pages";

// vite build --mode test の書き出しの元（vite.config.ts）。本番のページに、テストだけの版 b を足す。
// 本番の版 a は提供者のトークンが空なので、b にはトークンを持たせ、リンクが pt を持つ側も確かめる
const testVariantPage = createLandingVariantPage({
  variant: "b",
  listing: { ...appStoreListing, providerToken: "test-provider-token" },
  title: "nu-tori",
  description: "テストだけの LP の版です。",
  Content: ({ appStoreUrl }) => <AppStoreBadge href={appStoreUrl} />,
});

export default createSiteApp([...sitePages, testVariantPage]);
