import type { Child } from "hono/jsx";
import { raw } from "hono/html";
import { siteOrigin } from "./site-origin";
import type { SitePage } from "./site-page";

// 全ページで共通の外枠（<head>、ヘッダー、足）。ページを足すチケットが、そのページへのリンクを footerLinks に足す
export const SiteLayout = ({ page, children }: { page: SitePage; children: Child }) => (
  <>
    {raw("<!doctype html>")}
    <html lang="ja">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>{page.title}</title>
        <meta name="description" content={page.description} />
        {page.search.kind === "indexed" ? (
          <link rel="canonical" href={`${siteOrigin}${page.search.canonicalPath}`} />
        ) : (
          <meta name="robots" content="noindex" />
        )}
        <link rel="stylesheet" href="/site.css" />
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
              {footerLinks.map((link) => (
                <li>
                  <a href={link.href}>{link.label}</a>
                </li>
              ))}
            </ul>
          </nav>
          <p>医療の助言ではありません。持病のある方は、医師に相談してください。</p>
          <p>nu-tori for iPhone</p>
        </footer>
      </body>
    </html>
  </>
);

const footerLinks = [
  { href: "/privacy", label: "プライバシーポリシー" },
  { href: "/support", label: "サポート" },
  { href: "/announcements", label: "告知" },
];
