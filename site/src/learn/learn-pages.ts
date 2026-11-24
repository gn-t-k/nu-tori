import { createLearnPages } from "./create-learn-pages";
import { learnArticleCountToList, learnArticles } from "./learn-articles";

// 考え方のページのモジュール（learn）が外に出すもの。ページの一覧（site-pages.ts）はこれを並べるだけ
export const learnPages = createLearnPages(learnArticles, {
  listed: learnArticles.length >= learnArticleCountToList,
});
