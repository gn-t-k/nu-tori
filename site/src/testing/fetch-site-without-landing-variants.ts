import { env } from "cloudflare:workers";
import { siteOrigin } from "../site-origin";

// LP_VARIANTS を空にした Worker に投げる（vitest.config.ts）。本番の LP_VARIANTS に頼らずに、版が無いときの仮のページを確かめるため
export const fetchSiteWithoutLandingVariants = (
  path: string,
  init?: RequestInit,
): Promise<Response> => env.SITE_WITHOUT_LANDING_VARIANTS.fetch(new URL(path, siteOrigin), init);
