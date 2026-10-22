import { Hono } from "hono";
import { SiteLayout } from "./site-layout";
import { siteOrigin } from "./site-origin";
import { canonicalPathOf } from "./site-page";
import { sitePages } from "./site-pages";

// vite build が @hono/vite-ssg でこのアプリの経路を静的なファイルに書き出す。出したあとは動かない（振り分けは worker.ts）
const app = new Hono();

for (const page of sitePages) {
  app.get(page.outputPath, (c) =>
    c.html(
      <SiteLayout page={page}>
        <page.Content />
      </SiteLayout>,
    ),
  );
}

app.get("/sitemap.xml", (c) => {
  // LP の版はどれも / を正規の URL にするので、同じ URL を1つにまとめる
  const urls = new Set(
    sitePages.flatMap((page) => {
      const canonicalPath = canonicalPathOf(page);
      return canonicalPath === undefined ? [] : [`${siteOrigin}${canonicalPath}`];
    }),
  );
  const entries = [...urls].map((url) => `  <url><loc>${url}</loc></url>`);
  return c.body(
    [
      '<?xml version="1.0" encoding="UTF-8"?>',
      '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
      ...entries,
      "</urlset>",
      "",
    ].join("\n"),
    200,
    { "Content-Type": "application/xml" },
  );
});

app.get("/robots.txt", (c) =>
  c.text(`User-agent: *\nAllow: /\n\nSitemap: ${siteOrigin}/sitemap.xml\n`),
);

export default app;
