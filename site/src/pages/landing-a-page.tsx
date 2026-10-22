import { AppStoreBadge } from "../app-store-badge";
import { appStoreListing } from "../app-store-listing";
import { createLandingVariantPage } from "../create-landing-variant-page";
import { landingPageHead } from "../landing-page-head";

// LP の版 a。今は外枠とバッジだけの骨組みで、中身は「site: LP の版 a の中身を書く」で書く。
// LP_VARIANTS（wrangler.jsonc）に "a" を入れるまで、外からは見えない
export const landingAPage = createLandingVariantPage({
  variant: "a",
  listing: appStoreListing,
  ...landingPageHead,
  Content: ({ appStoreUrl }) => (
    <>
      <h1>nu-tori</h1>
      <AppStoreBadge href={appStoreUrl} />
    </>
  ),
});
