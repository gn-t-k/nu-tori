import { useContext, type Child } from "hono/jsx";
import { raw } from "hono/html";
import { AppStoreBadgePlacement } from "./app-store-badge-placement";
import { siteOrigin } from "./site-origin";
import { canonicalPathOf, type SitePage } from "./site-page";
import { sitePages } from "./site-pages";
import { webAnalytics } from "./web-analytics";

// 全ページで共通の外枠（<head>、ヘッダー、足）
export const SiteLayout = ({ page, children }: { page: SitePage; children: Child }) => {
  const canonicalPath = canonicalPathOf(page);
  return (
    <AppStoreBadgePlacement.Provider value={{ placed: false }}>
      {raw("<!doctype html>")}
      <html lang="ja">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title>{page.title}</title>
          <meta name="description" content={page.description} />
          {canonicalPath === undefined ? (
            <meta name="robots" content="noindex" />
          ) : (
            <link rel="canonical" href={`${siteOrigin}${canonicalPath}`} />
          )}
          <link rel="stylesheet" href="/site.css" />
          <script
            defer
            src={webAnalytics.beaconScriptUrl}
            data-cf-beacon={JSON.stringify({ token: webAnalytics.token })}
          />
        </head>
        <body>
          <header class="site-header">
            <a class="site-name" href="/">
              nu-tori
            </a>
          </header>
          <main>{children}</main>
          <footer class="site-footer">
            <nav>
              <ul>
                {sitePages.flatMap((linked) =>
                  linked.kind === "public"
                    ? [
                        <li>
                          <a href={linked.outputPath}>{linked.footerLabel}</a>
                        </li>,
                      ]
                    : [],
                )}
              </ul>
            </nav>
            <p>医療の助言ではありません。持病のある方は、医師に相談してください。</p>
            <p>nu-tori for iPhone</p>
            <AppleTrademarkNotice />
          </footer>
        </body>
      </html>
    </AppStoreBadgePlacement.Provider>
  );
};

// Apple のバッジの決まりで、商標の行はバッジを置いたページの足にだけ1回置く
const AppleTrademarkNotice = () =>
  useContext(AppStoreBadgePlacement)?.placed === true ? (
    <p>
      Apple および Apple ロゴは、米国およびその他の国で登録された Apple Inc. の商標です。App Store
      は、米国およびその他の国で登録された Apple Inc. のサービスマークです。
    </p>
  ) : null;
