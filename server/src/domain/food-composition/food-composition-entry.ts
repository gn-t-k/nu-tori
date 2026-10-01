import type { NutrientName } from "./nutrient-name";

// 成分表の1食品。栄養の値は可食部 100 g あたり。不明の項目（成分表の「-」）は持たず、Tr と (0) は 0 の項目を持つ
export type FoodCompositionEntry = {
  // 5 桁の食品番号。先頭の 0 を落とさないよう文字列
  foodNumber: string;
  // 成分表の食品名。階層を全角スペースでつなぐ（例: 「＜鳥肉類＞」「にわとり」「［若どり・主品目］」「むね」「皮なし」「生」）
  name: string;
  aliases: readonly string[];
  nutrients: Readonly<Partial<Record<NutrientName, number>>>;
};
