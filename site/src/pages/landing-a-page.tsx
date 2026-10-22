import { AppStoreBadge } from "../app-store-badge";
import { appStoreListing } from "../app-store-listing";
import { createLandingVariantPage } from "../create-landing-variant-page";

// LP の版 a。今は外枠とバッジだけの骨組みで、中身は「site: LP の版 a の中身を書く」で書く。
// LP_VARIANTS（wrangler.jsonc）に "a" を入れるまで、外からは見えない
export const landingAPage = createLandingVariantPage({
  variant: "a",
  listing: appStoreListing,
  // LP を出すまで / は仮のページを返し、テストが / の <title> を仮のページの題で確かめるので、題と説明を仮のページとそろえておく
  title: "nu-tori",
  description:
    "朝の体重と食事の写真から、1日に食べる量の目安を毎週合わせ直す iPhone のアプリです。",
  Content: ({ appStoreUrl }) => (
    <>
      <h1>nu-tori</h1>
      <AppStoreBadge href={appStoreUrl} />
    </>
  ),
});
