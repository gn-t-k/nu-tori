import { chartGeometry } from "./chart-geometry";
import { dailyGuideExample } from "./daily-guide-example";
import { formatExampleValue } from "./format-example-value";

const { assertWithin, scale, path } = chartGeometry;
const { kg } = formatExampleValue;

// 4週目の1日の目安を、見直さずに2年食べ続けたときの体重
export const PlateauFigure = ({ caption }: { caption: string }) => {
  const { plateau, plateauStart, plateauAfterOneYear, plateauAfterTwoYears } = dailyGuideExample;
  const [width, height, left, right, top, bottom] = [360, 220, 34, 20, 16, 30];
  const [lowKg, highKg] = [58, 80];
  assertWithin(
    "食べ続けたときの図",
    plateau.map((point) => point.trueWeightKg),
    lowKg,
    highKg,
  );
  const x = scale(plateauStart.week, plateauAfterTwoYears.week, left, width - right);
  const y = scale(lowKg, highKg, height - bottom, top);
  return (
    <figure class="figure">
      <div class="figure-scroll">
        <svg
          viewBox={`0 0 ${width} ${height}`}
          role="img"
          aria-label="同じ量を食べ続けると、体重の減り方がだんだん緩くなり、止まっていく"
        >
          {[60, 65, 70, 75].map((tick) => (
            <>
              <line class="grid" x1={left} x2={width - right} y1={y(tick)} y2={y(tick)} />
              <text class="tick" x={left - 6} y={y(tick) + 4} text-anchor="end">
                {tick}
              </text>
            </>
          ))}
          <path
            class="trend"
            d={path(plateau.map((point) => [x(point.week), y(point.trueWeightKg)]))}
          />
          <circle
            class="end trend-end"
            cx={x(plateauAfterOneYear.week)}
            cy={y(plateauAfterOneYear.trueWeightKg)}
            r="3.5"
          />
          <text
            class="value"
            x={x(plateauAfterOneYear.week) + 6}
            y={y(plateauAfterOneYear.trueWeightKg) - 12}
            text-anchor="start"
          >
            1年で {kg(plateauStart.trueWeightKg - plateauAfterOneYear.trueWeightKg, 1)} kg 減
          </text>
          <circle
            class="end trend-end"
            cx={x(plateauAfterTwoYears.week)}
            cy={y(plateauAfterTwoYears.trueWeightKg)}
            r="3.5"
          />
          <text
            class="value"
            x={x(plateauAfterTwoYears.week)}
            y={y(plateauAfterTwoYears.trueWeightKg) - 14}
            text-anchor="end"
          >
            次の1年は {kg(plateauAfterOneYear.trueWeightKg - plateauAfterTwoYears.trueWeightKg, 1)}{" "}
            kg 減
          </text>
          <text class="tick" x={x(plateauStart.week)} y={height - 10} text-anchor="start">
            今
          </text>
          <text class="tick" x={x(plateauAfterOneYear.week)} y={height - 10} text-anchor="middle">
            1年後
          </text>
          <text class="tick" x={x(plateauAfterTwoYears.week)} y={height - 10} text-anchor="end">
            2年後
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
