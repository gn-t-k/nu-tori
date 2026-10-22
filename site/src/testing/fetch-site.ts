import { env } from "cloudflare:workers";
import { siteOrigin } from "../site-origin";

// 出すときと同じく、run_worker_first に当たらないパスは Worker を通らずに assets から返る
export const fetchSite = (path: string, init?: RequestInit): Promise<Response> =>
  env.SITE.fetch(new URL(path, siteOrigin), init);
