import type { ListingCopy } from "./listing-copy.ts";

// 掲載用のスクリーンショット5枚の見出しと、載せる生の画面。合成のコマンドが Node のまま読むので、ほかのモジュールを import しない（型は消えるのでよい）。
// 並びと載せる生の画面と見出しの線は #867 の解決コメントの2。見出しの文は仮の文で、本番の文は #862 で書く
export const appStoreScreenshots: readonly AppStoreScreenshot[] = [
  {
    name: "01",
    headline: { status: "draft", text: "続けるほど、ちょうどいい量が分かる" },
    emphasis: "ちょうどいい量",
    screen: "step-guide",
  },
  {
    name: "02",
    headline: { status: "draft", text: "撮って送るだけ" },
    emphasis: "撮って",
    screen: "photo-estimated",
  },
  {
    name: "03",
    headline: { status: "draft", text: "撮り忘れたら、書いて送るだけ" },
    emphasis: "書いて",
    screen: "text-meal",
  },
  {
    name: "04",
    headline: { status: "draft", text: "材料ごとに、量から栄養を計算" },
    emphasis: "材料ごと",
    screen: "dish",
  },
  {
    name: "05",
    headline: { status: "draft", text: "目標までの道のりが見える" },
    emphasis: "道のり",
    screen: "weekly-review",
  },
];

export type AppStoreScreenshot = {
  // 書き出すファイルの名前（<name>.png）。並びが App Store に上げる順
  name: string;
  headline: ListingCopy;
  // 見出しの中で色を変える要の語（#867 の解決コメントの1）。見出しの文にそのまま含まれる一続きの文字で、最初に現れた所だけ色を変える。
  // 見出しの文とは別の欄に置き、見出しの文には印を入れない。文の決まり（listing-rule-violations.ts）は見出しの文をそのまま見る
  emphasis: string;
  // 載せる生の画面。端末は1枚に1台（#867 の解決コメントの1）
  screen: RawScreenName;
};

// 生の画面の名前。撮る UI テストとの約束（仕様 #853 の「撮る画面」）
export type RawScreenName =
  | "step-weigh"
  | "step-photo"
  | "step-guide"
  | "photo-estimated"
  | "text-meal"
  | "dish"
  | "weekly-review";
