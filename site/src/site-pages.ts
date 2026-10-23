import { announcementsPage } from "./pages/announcements-page";
import { dailyGuidePage } from "./pages/daily-guide-page";
import { landingAPage } from "./pages/landing-a-page";
import { landingPlaceholderPage } from "./pages/landing-placeholder-page";
import { legalPage } from "./pages/legal-page";
import { notFoundPage } from "./pages/not-found-page";
import { privacyPage } from "./pages/privacy-page";
import { supportPage } from "./pages/support-page";
import { termsPage } from "./pages/terms-page";
import type { SitePage } from "./site-page";

// 公開のページの並びが、外枠の足のリンクの並びになる
export const sitePages: readonly SitePage[] = [
  landingPlaceholderPage,
  landingAPage,
  privacyPage,
  termsPage,
  legalPage,
  supportPage,
  dailyGuidePage,
  announcementsPage,
  notFoundPage,
];
