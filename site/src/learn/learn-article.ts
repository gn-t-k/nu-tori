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
  // 本文。主張ごとに、研究で分かっていること（と図）、続けて nu-tori の作り
  claims: readonly LearnClaim[];
  Rules: FC;
  sources: readonly LearnSource[];
  // 資料に拠らず nu-tori が決めた決まり。出典の節の末に並べる
  decidedByNuTori: readonly string[];
};

// 主張の1つ。見出しは主張の文で、読点を使わない
export type LearnClaim = {
  heading: string;
  Research: FC;
  figure?: LearnFigure;
  // その主張に当たる nu-tori の作り。「nu-tori では」の小見出しの下に描く
  NuTori?: FC;
};

// 主張の図。site/public に置いた画像
export type LearnFigure = {
  src: string;
  alt: string;
  width: number;
  height: number;
};

// 出典の1件。一覧の集めた出典の節は、url で重なりを除く
export type LearnSource = {
  // 何の根拠か
  claim: string;
  citation: string;
  url: string;
  linkLabel: string;
};
