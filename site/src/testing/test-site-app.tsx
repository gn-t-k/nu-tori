import { AppStoreBadge } from "../app-store-badge";
import { appStoreListing } from "../app-store-listing";
import { createLandingVariantPage } from "../create-landing-variant-page";
import { createSiteApp } from "../create-site-app";
import { createLearnPages } from "../learn/create-learn-pages";
import { learnArticles } from "../learn/learn-articles";
import { learnPages } from "../learn/learn-pages";
import { sitePages } from "../site-pages";

// vite build --mode test の書き出しの元（vite.config.ts）。本番のページに、テストだけの版 b を足し、考え方のページを、並びの本数にかかわらず隠すのを外した形（6本そろったときの形）に置き換える
const testVariantPage = createLandingVariantPage({
  variant: "b",
  listing: appStoreListing,
  title: "nu-tori",
  description: "テストだけの LP の版です。",
  Content: ({ appStoreUrl }) => <AppStoreBadge href={appStoreUrl} />,
});

const listedLearnPages = createLearnPages(learnArticles, { listed: true });

export default createSiteApp([
  // 本番の並びの考え方のページの位置に、隠すのを外した形を差し込む（足のリンクの並びを本番と同じにする）
  ...sitePages.flatMap((page) =>
    page === learnPages[0] ? listedLearnPages : learnPages.includes(page) ? [] : [page],
  ),
  testVariantPage,
]);
