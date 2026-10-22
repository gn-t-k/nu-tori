import type { SitePage } from "../site-page";

// LP を出すまで / に返す仮のページ。名前と一言の説明だけを置き、公開のページへのリンクは外枠の足に任せる。バッジ・料金・画面の絵は置かない
export const landingPlaceholderPage: SitePage = {
  outputPath: "/_lp/_placeholder/",
  title: "nu-tori",
  description:
    "朝の体重と食事の写真から、1日に食べる量の目安を毎週合わせ直す iPhone のアプリです。",
  search: { kind: "indexed", canonicalPath: "/" },
  Content: () => (
    <>
      <h1>nu-tori</h1>
      <p>朝の体重と食事の写真から、1日に食べる量の目安を毎週合わせ直す iPhone のアプリです。</p>
    </>
  ),
};
