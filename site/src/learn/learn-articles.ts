import { calorieBalance } from "./articles/calorie-balance";
import type { LearnArticle } from "./learn-article";

// 考え方のページの並び。アプリで出会う順（目標を立てる → 目安と P・F・C を見る → 体重を量る → 毎週の見直し）に置く（#1110）。
// 一覧のページ、次のページへのリンク、一覧の集めた出典は、この並びから作る
export const learnArticles: readonly LearnArticle[] = [calorieBalance];
