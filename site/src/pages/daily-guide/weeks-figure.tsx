import type { Child } from "hono/jsx";
import { chartGeometry } from "./chart-geometry";
import { dailyGuideExample } from "./daily-guide-example";
import { match } from "ts-pattern";
import { formatExampleValue } from "./format-example-value";

const { assertWithin, scale, path } = chartGeometry;
const { kcal } = formatExampleValue;

// 使い始めてから5週目までの、推定消費カロリーと1日の目安（段）と、体が本当に使うカロリー（点線）
export const WeeksFigure = ({ caption, labels }: { caption: Child; labels: WeeksFigureLabels }) => {
  const { initial, reviews, days, lastDay, lastReview } = dailyGuideExample;
  const [width, height, left, right, top, bottom] = [360, 250, 40, 84, 16, 30];
  // 週 0〜5（4回の見直しのあと1週）
  const x = scale(0, 5, left, width - right);
  const estimates = [initial.kcal, ...reviews.map((review) => review.expenditureKcal)];
  const guides = [initial.guideKcal, ...reviews.map((review) => review.guideKcal)];
  const [lowKcal, highKcal] = [1500, 2450];
  // 線の上と下に値の文字を置くので、その分だけ軸の端から離す
  const labelMarginKcal = 30;
  assertWithin(
    "推定消費カロリーの図",
    [...estimates, ...guides, ...days.map((day) => day.trueExpenditureKcal)],
    lowKcal + labelMarginKcal,
    highKcal - labelMarginKcal,
  );
  const y = scale(lowKcal, highKcal, height - bottom, top);
  const stepPoints = (values: number[]) =>
    values.flatMap((value, i) => [[x(i), y(value)] as const, [x(i + 1), y(value)] as const]);
  const steps = (values: number[]) => path(stepPoints(values));
  // 推定消費カロリーの段を右へたどり、目安の段を左へ戻って閉じる
  const gapArea = `${path([...stepPoints(estimates), ...stepPoints(guides).toReversed()])} Z`;
  const tones = match(labels.emphasized)
    .with("estimate", () => ({ estimate: "", guide: " muted" }))
    .with("guide", () => ({ estimate: " muted", guide: "" }))
    .exhaustive();
  // 週の初めの日ごとと、4週目の終わり
  const truthLine = path(
    days
      .filter((_, i) => i % 7 === 0 || i === days.length - 1)
      .map((day, i, sampled) => [x(i === sampled.length - 1 ? 4 : i), y(day.trueExpenditureKcal)]),
  );
  const lastEstimate = lastReview.expenditureKcal;
  const lastGuide = lastReview.guideKcal;
  return (
    <figure class="figure">
      <div class="figure-scroll">
        <svg viewBox={`0 0 ${width} ${height}`} role="img" aria-label={labels.description}>
          {[1600, 1800, 2000, 2200, 2400].map((tick) => (
            <>
              <line class="grid" x1={left} x2={x(5)} y1={y(tick)} y2={y(tick)} />
              <text class="tick" x={left - 6} y={y(tick) + 4} text-anchor="end">
                {kcal(tick)}
              </text>
            </>
          ))}
          {labels.gap === undefined ? undefined : <path class="difference" d={gapArea} />}
          <path class="truth" d={truthLine} />
          <path class={`step${tones.estimate}`} d={steps(estimates)} />
          <path class={`step${tones.guide}`} d={steps(guides)} />
          {estimates.map((value, i) => (
            <text
              class={`value${tones.estimate}`}
              x={(x(i) + x(i + 1)) / 2}
              y={y(value) - 6}
              text-anchor="middle"
            >
              {kcal(value)}
            </text>
          ))}
          {guides.map((value, i) => (
            <text
              class={`value${tones.guide}`}
              x={(x(i) + x(i + 1)) / 2}
              y={y(value) + 15}
              text-anchor="middle"
            >
              {kcal(value)}
            </text>
          ))}
          {lineLabels(labels.estimate, y(lastEstimate), `series-label${tones.estimate}`, x(5) + 6)}
          {lineLabels(labels.guide, y(lastGuide), `series-label${tones.guide}`, x(5) + 6)}
          {labels.gap === undefined
            ? undefined
            : lineLabels(
                labels.gap,
                (y(lastEstimate) + y(lastGuide)) / 2,
                "series-label faint",
                x(5) + 6,
              )}
          <text class="series-label faint" x={x(4) + 4} y={y(lastDay.trueExpenditureKcal) - 22}>
            {labels.truth}
          </text>
          {[0, 1, 2, 3, 4].map((week) => (
            <text class="tick" x={(x(week) + x(week + 1)) / 2} y={height - 10} text-anchor="middle">
              {week + 1}週目
            </text>
          ))}
          <text class="tick" x={left - 6} y={top - 4} text-anchor="end">
            kcal
          </text>
        </svg>
      </div>
      <figcaption>{caption}</figcaption>
    </figure>
  );
};

// 線の名前。出し方のページは GLOSSARY の語で書き、LP は GLOSSARY の語を画面の名前にだけ使う（docs/agents/marketing.md）ので言い換える
type Lines = readonly [string] | readonly [string, string];
type WeeksFigureLabels = {
  description: string;
  estimate: Lines;
  guide: Lines;
  truth: string;
  // 色を付ける線。出し方のページは推定消費カロリーが直るところを、LP は見出しが目安なので目安を見せる
  emphasized: "estimate" | "guide";
  // 推定消費カロリーと1日の目安の差の名前。渡すと、差に色を敷く
  gap?: Lines;
};

// 1行なら線の高さに、2行なら線をはさんで置く
const lineLabels = (lines: Lines, lineY: number, className: string, labelX: number) =>
  lines.map((line, i) => (
    <text class={className} x={labelX} y={lineY + (lines.length === 1 ? 4 : i * 14 - 2)}>
      {line}
    </text>
  ));
