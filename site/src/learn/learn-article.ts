import type { FC } from "hono/jsx";

// 考え方のページの1問。ページを足す人は、これを1つ書いて並び（learn-articles.ts）に1行足す。節の並びとリンクは create-learn-pages.tsx が描く
export type LearnArticle = {
  // パスの名前。/learn/<slug> に書き出す
  slug: string;
  // 世の中の問いの題。<h1> と <title> に使う
  question: string;
  description: string;
  // 題のすぐ下の導入。状況・困りごと・問い・答えの順に書き、答え（このページの結論）を最初に言い切る
  Lead: FC;
  // 本文。主張ごとに、研究で分かっていること（図は本文の中に LearnFigure で置く）、続けて nu-tori の作り。nu-tori の計算の決まりも、当たる主張の「nu-tori では」に地の文で書く
  claims: readonly LearnClaim[];
  sources: readonly LearnSource[];
  // 資料に拠らず nu-tori が決めた決まり。出典の節の末に並べる
  decidedByNuTori: readonly string[];
};

// 主張の1つ。見出しは主張の文で、読点を使わない
export type LearnClaim = {
  heading: string;
  Research: FC;
  // その主張に当たる nu-tori の作り。「nu-tori では」の小見出しの下に描く
  NuTori?: FC;
};

// 出典の1件。一覧の集めた出典の節は、url で重なりを除く
export type LearnSource = {
  // 何の根拠か
  claim: string;
  citation: string;
  url: string;
  linkLabel: string;
};
