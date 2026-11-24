import { env } from "cloudflare:workers";
import { siteOrigin } from "../site-origin";

// 考え方のページの隠すのを外した形（テストの書き出し。src/testing/test-site-app.tsx）を配る Worker に投げる（vitest.config.ts）。
// 並びが6本にそろう前に、そろったあとの形を確かめるため
export const fetchSiteWithLearnPagesListed = (
  path: string,
  init?: RequestInit,
): Promise<Response> => env.SITE_WITH_LEARN_PAGES_LISTED.fetch(new URL(path, siteOrigin), init);
