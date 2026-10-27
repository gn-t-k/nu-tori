import { chartGeometry } from "./chart-geometry";
import { dailyGuideExample } from "./daily-guide-example";
import { formatExampleValue } from "./format-example-value";

const { assertWithin, scale, path } = chartGeometry;
const { kcal } = formatExampleValue;

// 使い始めてから5週目までの、推定消費カロリーと1日の目安（段）と、体が本当に使うカロリー（点線）
export const WeeksFigure = ({ caption }: { caption: string }) => {
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
  const steps = (values: number[]) =>
    path(
      values.flatMap((value, i) => [
        [x(i), y(value)],
        [x(i + 1), y(value)],
      ]),
    );
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
        <svg
          viewBox={`0 0 ${width} ${height}`}
          role="img"
          aria-label="推定消費カロリーが毎週の見直しで本当に使うカロリーに近づき、1日の目安もそれに沿って下がる"
        >
          {[1600, 1800, 2000, 2200, 2400].map((tick) => (
            <>
              <line class="grid" x1={left} x2={x(5)} y1={y(tick)} y2={y(tick)} />
              <text class="tick" x={left - 6} y={y(tick) + 4} text-anchor="end">
                {kcal(tick)}
              </text>
            </>
          ))}
          <path class="truth" d={truthLine} />
          <path class="trend" d={steps(estimates)} />
          <path class="guide" d={steps(guides)} />
          {estimates.map((value, i) => (
            <text class="value" x={(x(i) + x(i + 1)) / 2} y={y(value) - 6} text-anchor="middle">
              {kcal(value)}
            </text>
          ))}
          {guides.map((value, i) => (
            <text
              class="value muted"
              x={(x(i) + x(i + 1)) / 2}
              y={y(value) + 15}
              text-anchor="middle"
            >
              {kcal(value)}
            </text>
          ))}
          <text class="series-label" x={x(5) + 6} y={y(lastEstimate) - 2}>
            推定消費
          </text>
          <text class="series-label" x={x(5) + 6} y={y(lastEstimate) + 12}>
            カロリー
          </text>
          <text class="series-label muted" x={x(5) + 6} y={y(lastGuide) + 4}>
            1日の目安
          </text>
          <text class="series-label faint" x={x(4) + 4} y={y(lastDay.trueExpenditureKcal) - 22}>
            本当に使うカロリー
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
