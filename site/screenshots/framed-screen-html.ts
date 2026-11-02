import type { Bezel } from "./load-bezel.ts";

// 生の画面を枠の穴に敷き、その上に枠をそのまま重ねる。置いた要素の幅いっぱいに広がり、高さは枠の縦横比で決まる。
// Apple の決まりで、枠は手を加えずに使う（切る・傾ける・影を付ける・画面から何かをはみ出させるのは不可。https://developer.apple.com/app-store/marketing/guidelines/ の Apple Product Images）
export const framedScreenHtml = (bezel: Bezel, screenDataUrl: string): string => {
  // 穴の縁のなめらかにした所が透けないよう、画面を枠の下に1ピクセルずつ広げて敷く
  const bleed = 1;
  const left = bezel.screen.left - bleed;
  const top = bezel.screen.top - bleed;
  const width = bezel.screen.width + bleed * 2;
  const height = bezel.screen.height + bleed * 2;
  const radius = bezel.screen.cornerRadius + bleed;
  const screenStyle = [
    "position: absolute",
    `left: ${percent(left, bezel.width)}`,
    `top: ${percent(top, bezel.height)}`,
    `width: ${percent(width, bezel.width)}`,
    `height: ${percent(height, bezel.height)}`,
    `border-radius: ${percent(radius, width)} / ${percent(radius, height)}`,
    "object-fit: cover",
  ].join("; ");
  return [
    `<div style="position: relative; width: 100%; aspect-ratio: ${bezel.width} / ${bezel.height}">`,
    `<img alt="" src="${screenDataUrl}" style="${screenStyle}">`,
    `<img alt="" src="${bezel.dataUrl}" style="position: absolute; inset: 0; width: 100%; height: 100%">`,
    "</div>",
  ].join("");
};

const percent = (value: number, whole: number) => `${(value / whole) * 100}%`;
