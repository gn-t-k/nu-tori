import { createLearnPages } from "./create-learn-pages";
import { learnArticles } from "./learn-articles";

// 最初に出す本数（#1110 の6本）。site は1本ずつ main に入れて出すので、並びがこの本数にそろうまで考え方のページを隠す。learnPages がトップレベルで読むので、その上に置く
const learnArticleCountToList = 6;

// 考え方のページのモジュール（learn）が外に出すもの。ページの一覧（site-pages.ts）はこれを並べるだけ
export const learnPages = createLearnPages(learnArticles, {
  listed: learnArticles.length >= learnArticleCountToList,
});
