import { chartGeometry } from "./chart-geometry";
import { dailyGuideExample } from "./daily-guide-example";
import { formatExampleValue } from "./format-example-value";

const { scale, path } = chartGeometry;
const { kg, shortMonthDay, signedKg } = formatExampleValue;

// 例の週に、nu-tori が予想した体重の傾向の動き（点線）と、実際の体重の傾向（実線）のずれ
export const ReviewFigure = ({ caption }: { caption: string }) => {
  const review = dailyGuideExample.exampleReview;
  const { days } = dailyGuideExample;
  // 見直した週の前の日曜から、見直した週の日曜まで
  const weekEndIndex = days.findIndex((day) => day.calendarDay === review.weekLastDay);
  const segment = days.slice(weekEndIndex - 7, weekEndIndex + 1);
  const first = segment[0];
  const last = segment.at(-1);
  if (first === undefined || last === undefined) throw new Error("見直しの図に日が無い");
  const startKg = first.trendKg;
  const predictedEndKg = startKg + review.predictedWeightChangeKg;
  const actualEndKg = last.trendKg;
  const [width, height, left, right, top, bottom] = [360, 240, 34, 96, 16, 30];
  const x = scale(0, 7, left, width - right);
  const lowKg = Math.min(predictedEndKg, actualEndKg) - 0.15;
  const highKg = startKg + 0.2;
  const y = scale(lowKg, highKg, height - bottom, top);
  const ticks: number[] = [];
  for (
    let tick = Math.ceil(lowKg * 10) / 10;
    tick <= highKg;
    tick = Math.round((tick + 0.1) * 10) / 10
  ) {
    ticks.push(tick);
  }
  const gapX = x(7) + 10;
  const gapMiddleY = (y(actualEndKg) + y(predictedEndKg)) / 2;
  return (
    <figure class="figure">
      <div class="figure-scroll">
        <svg
          viewBox={`0 0 ${width} ${height}`}
          role="img"
          aria-label="予想した体重の動きと、実際の体重の傾向のずれ"
        >
          {ticks.map((tick) => (
            <>
              <line class="grid" x1={left} x2={x(7)} y1={y(tick)} y2={y(tick)} />
              <text class="tick" x={left - 6} y={y(tick) + 4} text-anchor="end">
                {tick.toFixed(1)}
              </text>
            </>
          ))}
          <path
            class="predicted"
            d={path([
              [x(0), y(startKg)],
              [x(7), y(predictedEndKg)],
            ])}
          />
          <path class="trend" d={path(segment.map((day, i) => [x(i), y(day.trendKg)]))} />
          <circle class="end" cx={x(7)} cy={y(predictedEndKg)} r="3.5" />
          <circle class="end trend-end" cx={x(7)} cy={y(actualEndKg)} r="3.5" />
          <text
            class="series-label"
            x={x(0) + 4}
            y={y(Math.max(...segment.map((day) => day.trendKg))) - 10}
          >
            実際の傾向 {signedKg(review.actualWeightChangeKg)} kg
          </text>
          <text
            class="series-label muted"
            x={x(3)}
            y={y(startKg + (review.predictedWeightChangeKg * 3) / 7) + 20}
            text-anchor="middle"
          >
            予想 {signedKg(review.predictedWeightChangeKg)} kg
          </text>
          <path class="gap" d={`M${gapX} ${y(actualEndKg)} h6 V${y(predictedEndKg)} h-6`} />
          <text class="gap-label" x={gapX + 12} y={gapMiddleY - 2}>
            ずれ
          </text>
          <text class="gap-label" x={gapX + 12} y={gapMiddleY + 14}>
            {kg(review.deviationKg, 2)} kg
          </text>
          <text class="tick" x={x(0)} y={height - 10} text-anchor="start">
            {shortMonthDay(first.calendarDay)}（日）
          </text>
          <text class="tick" x={x(7)} y={height - 10} text-anchor="end">
            {shortMonthDay(last.calendarDay)}（日）
          </text>
          <text class="tick" x={left - 6} y={top - 4} text-anchor="end">
            kg
          </text>
        </svg>
      </div>
      <figcaption>{caption}</figcaption>
    </figure>
  );
};
