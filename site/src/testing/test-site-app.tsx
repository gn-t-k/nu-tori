import { AppStoreBadge } from "../app-store-badge";
import { appStoreListing } from "../app-store-listing";
import { createLandingVariantPage } from "../create-landing-variant-page";
import { createSiteApp } from "../create-site-app";
import { sitePages } from "../site-pages";

// vite build --mode test の書き出しの元（vite.config.ts）。本番のページに、テストだけの版 b を足す
const testVariantPage = createLandingVariantPage({
  variant: "b",
  listing: appStoreListing,
  title: "nu-tori",
  description: "テストだけの LP の版です。",
  Content: ({ appStoreUrl }) => <AppStoreBadge href={appStoreUrl} />,
});

export default createSiteApp([...sitePages, testVariantPage]);
