import type { ListingCopy } from "./listing-copy.ts";

// 掲載用のスクリーンショット5枚の見出しと、載せる生の画面。合成のコマンドが Node のまま読むので、ほかのモジュールを import しない（型は消えるのでよい）。
// 並びと載せる生の画面と見出しの線は #867 の解決コメントの2で、#862 で本番の文にした
export const appStoreScreenshots: readonly AppStoreScreenshot[] = [
  {
    name: "01",
    // 何が手に入るか。サブタイトルの線から「あなたに」を落とした。画面は「1日の目安が変わりました」の知らせ
    headline: { status: "final", text: "続けるほど、ちょうどいい量が分かる" },
    emphasis: "ちょうどいい量",
    screen: "step-guide",
  },
  {
    name: "02",
    // LP の手順とプロモーション用テキストの「食べる前に撮る」を足し、いつ撮るかを言う
    headline: { status: "final", text: "食べる前に、撮って送るだけ" },
    emphasis: "撮って送る",
    screen: "photo-estimated",
  },
  {
    name: "03",
    // 2枚目と「〜て送るだけ」でそろえ、要の語も「撮って送る」と対にする
    headline: { status: "final", text: "撮り忘れたら、書いて送るだけ" },
    emphasis: "書いて送る",
    screen: "text-meal",
  },
  {
    name: "04",
    // 画面に出ている材料ごとのグラム数と主な栄養の並びをそのまま言う
    headline: { status: "final", text: "材料ごとの量から、栄養を計算" },
    emphasis: "材料ごとの量",
    screen: "dish",
  },
  {
    name: "05",
    // 画面の「このままだと期限に 2.7 kg 届きません」と体重の傾向の線を、見出しの語にした
    headline: { status: "final", text: "このままで目標に届くかが見える" },
    emphasis: "目標に届くか",
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
type RawScreenName =
  | "step-weigh"
  | "step-photo"
  | "step-guide"
  | "photo-estimated"
  | "text-meal"
  | "dish"
  | "weekly-review";
