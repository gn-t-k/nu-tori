import { chartGeometry } from "./chart-geometry";
import { dailyGuideExample } from "./daily-guide-example";
import { formatExampleValue } from "./format-example-value";

const { assertWithin, scale, path } = chartGeometry;
const { shortMonthDay } = formatExampleValue;

// 毎朝の体重（点）と体重の傾向（線）。使い始める前の 14 日から4週目の終わりまで
export const TrendFigure = ({ caption }: { caption: string }) => {
  const series = [...dailyGuideExample.priorDays, ...dailyGuideExample.days];
  const first = series[0];
  const last = series.at(-1);
  if (first === undefined || last === undefined) throw new Error("体重の図に日が無い");
  const startIndex = dailyGuideExample.priorDays.length;
  const [width, height, left, right, top, bottom] = [360, 230, 34, 74, 14, 30];
  const [lowKg, highKg] = [76.6, 79.2];
  assertWithin(
    "体重の図",
    series.flatMap((day) => [day.weightKg, day.trendKg]),
    lowKg,
    highKg,
  );
  const x = scale(0, series.length - 1, left, width - right);
  const y = scale(lowKg, highKg, height - bottom, top);
  return (
    <figure class="figure">
      <div class="figure-scroll">
        <svg
          viewBox={`0 0 ${width} ${height}`}
          role="img"
          aria-label="毎朝の体重は日によって0.5 kg ほど上下するが、体重の傾向はなめらかに動く"
        >
          {[77, 78, 79].map((tick) => (
            <>
              <line class="grid" x1={left} x2={width - right} y1={y(tick)} y2={y(tick)} />
              <text class="tick" x={left - 6} y={y(tick) + 4} text-anchor="end">
                {tick}
              </text>
            </>
          ))}
          <line
            class="marker"
            x1={x(startIndex)}
            x2={x(startIndex)}
            y1={top}
            y2={height - bottom}
          />
          <text class="tick" x={x(startIndex) + 4} y={top + 10}>
            使い始めた日
          </text>
          {series.map((day, i) => (
            <circle class="dot" cx={x(i).toFixed(1)} cy={y(day.weightKg).toFixed(1)} r="2.6" />
          ))}
          <path class="trend" d={path(series.map((day, i) => [x(i), y(day.trendKg)]))} />
          <text class="series-label" x={width - right + 6} y={y(last.trendKg) + 4}>
            体重の傾向
          </text>
          <text class="series-label muted" x={width - right + 6} y={y(last.weightKg) + 16}>
            毎朝の体重
          </text>
          <text class="tick" x={x(0)} y={height - 10} text-anchor="start">
            {shortMonthDay(first.calendarDay)}
          </text>
          <text class="tick" x={x(series.length - 1)} y={height - 10} text-anchor="end">
            {shortMonthDay(last.calendarDay)}
          </text>
          <text class="tick" x={left - 6} y={top - 2} text-anchor="end">
            kg
          </text>
        </svg>
      </div>
      <figcaption>{caption}</figcaption>
    </figure>
  );
};
