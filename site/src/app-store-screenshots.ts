import type { ListingCopy } from "./listing-copy.ts";

// 掲載用のスクリーンショット5枚の見出しと、載せる生の画面。合成のコマンドが Node のまま読むので、ほかのモジュールを import しない（型は消えるのでよい）。
// 見出しの文は #597 の解決コメントの9の仮の文。本番の文は #816 を読んで #862 で書く。何枚目にどの生の画面を載せるかも、仕様 #853 の「撮る画面」の表の仮の割り当てで、#862 で決め直してよい
export const appStoreScreenshots: readonly AppStoreScreenshot[] = [
  {
    name: "01",
    headline: { status: "draft", text: "朝、体重を量る。食べる前に撮る。毎週、目安が変わる。" },
    screens: ["step-weigh", "step-photo", "step-guide"],
  },
  {
    name: "02",
    headline: { status: "draft", text: "撮るだけ。撮り忘れたら、書くだけ。" },
    screens: ["photo-estimated", "text-meal"],
  },
  {
    name: "03",
    headline: { status: "draft", text: "日本食品標準成分表で数える" },
    screens: ["dish-detail"],
  },
  {
    name: "04",
    headline: { status: "draft", text: "毎週の体重の動きで、1日に食べる量の目安が変わる" },
    screens: ["weekly-review"],
  },
  {
    name: "05",
    headline: { status: "draft", text: "撮ったら、確定を押さずに食べはじめられる" },
    screens: ["eat-while-estimating"],
  },
];

export type AppStoreScreenshot = {
  // 書き出すファイルの名前（<name>.png）。並びが App Store に上げる順
  name: string;
  headline: ListingCopy;
  screens: readonly RawScreenName[];
};

// 生の画面の名前。撮る UI テストとの約束（仕様 #853 の「撮る画面」）
export type RawScreenName =
  | "step-weigh"
  | "step-photo"
  | "step-guide"
  | "photo-estimated"
  | "text-meal"
  | "dish-detail"
  | "weekly-review"
  | "eat-while-estimating";
