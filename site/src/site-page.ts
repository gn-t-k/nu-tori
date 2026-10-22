import type { FC } from "hono/jsx";

export type SitePage = {
  // 書き出す先。末尾のスラッシュ無しは <パス>.html に、末尾のスラッシュ付きは <パス>/index.html に書き出す
  outputPath: string;
  title: string;
  description: string;
  Content: FC;
} & SitePageKind;

// 検索に載せるページだけが正規の URL を持ち、sitemap.xml に並ぶ
export const canonicalPathOf = (page: SitePage): string | undefined =>
  (
    {
      public: page.outputPath,
      landing: "/",
      unindexed: undefined,
    } satisfies Record<SitePage["kind"], string | undefined>
  )[page.kind];

type SitePageKind =
  // 公開のページ。書き出す先のパスを正規の URL にして、検索に載せる
  | { kind: "public" }
  // / に返すページ（仮のページと LP の版）。振り分けの Worker が /_lp/<名前>/ を読んで / で返すので、正規の URL はどれも / にする
  | { kind: "landing" }
  | { kind: "unindexed" };
