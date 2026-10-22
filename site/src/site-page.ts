import type { FC } from "hono/jsx";

export type SitePage = {
  // 書き出す先。末尾のスラッシュ無しは <パス>.html に、末尾のスラッシュ付きは <パス>/index.html に書き出す
  outputPath: string;
  title: string;
  description: string;
  search: SitePageSearch;
  Content: FC;
};

// 検索に載せるページは、正規の URL を持ち、sitemap.xml に並ぶ。正規の URL のパスは末尾のスラッシュ無し（/ を除く）。LP の版は、どれも / にする
type SitePageSearch = { kind: "indexed"; canonicalPath: string } | { kind: "unindexed" };
