import { dailyGuidePage } from "./pages/daily-guide-page";
import { landingPlaceholderPage } from "./pages/landing-placeholder-page";
import { notFoundPage } from "./pages/not-found-page";
import { privacyPage } from "./pages/privacy-page";
import type { SitePage } from "./site-page";

// 書き出し、sitemap.xml、<head>、テストがここを読む。ページを足すときは、ここに1つ足し、外枠の足のリンク（site-layout.tsx）も足す
export const sitePages: readonly SitePage[] = [
  landingPlaceholderPage,
  privacyPage,
  dailyGuidePage,
  notFoundPage,
];
