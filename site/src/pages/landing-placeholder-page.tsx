import { landingPageHead } from "../landing-page-head";
import type { SitePage } from "../site-page";

// LP を出すまで / に返す仮のページ。名前と一言の説明だけを置き、公開のページへのリンクは外枠の足に任せる。バッジ・料金・画面の絵は置かない
export const landingPlaceholderPage: SitePage = {
  outputPath: "/_lp/_placeholder/",
  ...landingPageHead,
  kind: "landing",
  Content: () => (
    <>
      <h1>nu-tori</h1>
      <p>{landingPageHead.description}</p>
    </>
  ),
};
