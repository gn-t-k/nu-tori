import { env } from "cloudflare:workers";
import { siteOrigin } from "../site-origin";

// LP_VARIANTS を a と b にし、版を選ぶ乱数を b を引く値にした Worker に投げる（vitest.config.ts）。本番の LP_VARIANTS に頼らずに振り分けを確かめるため
export const fetchSiteWithLandingVariants = (path: string, init?: RequestInit): Promise<Response> =>
  env.SITE_WITH_LANDING_VARIANTS.fetch(new URL(path, siteOrigin), init);
