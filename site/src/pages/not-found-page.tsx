import type { SitePage } from "../site-page";

// 一覧に無いパスに返す（wrangler.jsonc の not_found_handling）
export const notFoundPage: SitePage = {
  outputPath: "/404",
  title: "ページが見つかりません | nu-tori",
  description: "お探しのページは見つかりませんでした。",
  search: { kind: "unindexed" },
  Content: () => (
    <>
      <h1>ページが見つかりません</h1>
      <p>
        お探しのページは見つかりませんでした。<a href="/">nu-tori のトップ</a>からお探しください。
      </p>
    </>
  ),
};
