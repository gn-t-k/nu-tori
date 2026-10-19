import { match } from "ts-pattern";
import type { Pace } from "../../../goal/domain/compute-pace";
import type { NutrientAmount } from "../../../ingredient/domain/nutrient-amount";
import { computeDayOfWeek } from "../../../domain/compute-day-of-week";
import type { DayOfWeek } from "../../../domain/day-of-week";
import type {
  MainNutrients,
  ReplyContext,
  ReplyContextGoal,
  ReplyContextStructuredValues,
  ReplyContextWeeklyReview,
  ReplyContextWindowEntry,
} from "../reply-context";
import { maintenanceBandKg } from "../../../goal/domain/maintenance-band-kg";

// 提供元に渡す文脈の文の塊。変わらない指示のあとに、この並びのまま置く（前の塊ほど変わらないので、キャッシュが効く）
export type ReplyContextBlock = {
  kind: "window" | "structured_values" | "new_utterance";
  text: string;
};

export const renderReplyContext = (context: ReplyContext): readonly ReplyContextBlock[] => [
  { kind: "window", text: renderWindow(context.window) },
  { kind: "structured_values", text: renderStructuredValues(context.structuredValues) },
  {
    kind: "new_utterance",
    text: `${formatDateTime(context.newUtterance.at)} ユーザー: ${context.newUtterance.body}`,
  },
];

const renderWindow = (window: readonly ReplyContextWindowEntry[]): string =>
  [
    "# 直近の会話と記録",
    ...(window.length === 0
      ? ["（直近 72 時間の会話はありません）"]
      : window.map((entry) =>
          match(entry)
            .with(
              { type: "user_utterance" },
              ({ at, body }) => `${formatDateTime(at)} ユーザー: ${body}`,
            )
            .with(
              { type: "ai_utterance" },
              ({ at, body }) => `${formatDateTime(at)} あなた: ${body}`,
            )
            .with(
              { type: "meal_recorded" },
              ({ at, mealId, dishNames }) =>
                `${formatDateTime(at)} 食事を記録（${formatDishNames(dishNames)}。食事 ID: ${mealId}）`,
            )
            .with(
              { type: "weight_recorded" },
              ({ at, weightKg }) =>
                `${formatDateTime(at)} 体重を記録（${formatNumber(weightKg, 1)} kg）`,
            )
            .exhaustive(),
        )),
  ].join("\n");

const renderStructuredValues = (values: ReplyContextStructuredValues): string =>
  [
    "# 記録の値",
    `送った日時: ${formatDateTime(values.sentAt.at)}`,
    "",
    "## 今日の食事",
    ...(values.todayMeals.length === 0
      ? ["なし"]
      : values.todayMeals.flatMap(({ mealId, eatenAt, estimation, dishes }) => [
          `- ${formatTime(eatenAt)}（食事 ID: ${mealId}）${match(estimation)
            .with("awaiting", () => " 料理と栄養を推定しているところ")
            .with("failed", () => " 料理と栄養を推定できなかった")
            .with("settled", () => "")
            .exhaustive()}`,
          ...dishes.map(
            ({ name, quantity, nutrients }) =>
              `  - ${name}${quantity === undefined ? "" : `（${formatNumber(quantity.value, 1)} ${quantity.unit}）`}: ${formatNutrients(nutrients)}`,
          ),
        ])),
    ...(values.todayNutrients === undefined
      ? []
      : [`今日の合計: ${formatNutrients(values.todayNutrients)}`]),
    "",
    "## 昨日の食事",
    ...(values.yesterdayMeals.length === 0
      ? ["なし"]
      : values.yesterdayMeals.map(
          ({ mealId, eatenAt, dishNames }) =>
            `- ${formatTime(eatenAt)} ${formatDishNames(dishNames)}（食事 ID: ${mealId}）`,
        )),
    "",
    "## 前の 7 日の合計",
    ...values.previousDays.map((day) =>
      day.recorded
        ? `- ${formatDate(day.calendarDay)}: ${formatNutrients(day.nutrients)}`
        : `- ${formatDate(day.calendarDay)}: 記録なし`,
    ),
    "",
    "## 体重の傾向（週ごと）",
    ...values.weeklyWeightTrend.map(
      ({ firstDay, lastDay, trendKg }) =>
        `- ${formatDate(firstDay)}〜${formatDate(lastDay)}: ${trendKg === undefined ? "なし" : `${formatNumber(trendKg, 1)} kg`}`,
    ),
    "",
    `最後の体重記録: ${
      values.lastWeightRecord === undefined
        ? "なし"
        : `${formatDateTime(values.lastWeightRecord.at)} ${formatNumber(values.lastWeightRecord.weightKg, 1)} kg`
    }`,
    // 目標を立てる前の人には節ごと書かない（返事の指示が、1日の目安の無いときの代わりの文を持つ）
    ...(values.goal === undefined ? [] : ["", ...renderGoal(values.goal)]),
  ].join("\n");

const renderGoal = ({
  direction,
  deadlineOn,
  targetWeightKg,
  dailyGuide,
  expenditureKcal,
  latestWeeklyReview,
  pace,
}: ReplyContextGoal): string[] => [
  "## 目標",
  `${match(direction)
    .with("lose", () => "減量")
    .with("gain", () => "増量")
    .with("maintain", () => "維持")
    .exhaustive()}。${deadlineOn === undefined ? "" : `期限 ${deadlineOn.slice(0, 4)}/${formatDate(deadlineOn)}、`}目標体重 ${formatNumber(targetWeightKg, 1)} kg`,
  `今日の1日の目安: ${
    dailyGuide === undefined
      ? "なし"
      : formatNutrients({
          energyKcal: { type: "exactly", value: dailyGuide.energyKcal },
          proteinG: { type: "exactly", value: dailyGuide.proteinG },
          fatG: { type: "exactly", value: dailyGuide.fatG },
          carbohydrateG: { type: "exactly", value: dailyGuide.carbohydrateG },
        })
  }`,
  `推定消費カロリー: ${expenditureKcal === undefined ? "なし" : `${formatNumber(expenditureKcal, 0)} kcal`}`,
  `ペース: ${renderPace(pace)}`,
  ...(latestWeeklyReview === undefined ? [] : renderWeeklyReview(latestWeeklyReview)),
];

const renderPace = (pace: Pace | undefined): string =>
  pace === undefined
    ? "なし"
    : match(pace)
        .with({ status: "onTrack" }, () => "今の体重の傾向の動きのままなら、期限に目標体重へ届く")
        .with(
          { status: "behind" },
          ({ shortfallKg }) =>
            `今の体重の傾向の動きのままだと、期限に目標体重まで ${shortfallKg.toFixed(1)} kg 届かない`,
        )
        .with(
          { status: "inconclusive" },
          ({ weightRecordDayCount }) =>
            `言い切れない（直近 14 日に体重を記録した日が ${weightRecordDayCount} 日しかない）`,
        )
        .with({ status: "pending" }, () => "まだ出ない（目標を立てて 14 日たっていない）")
        .with({ status: "unavailable" }, () => "なし（期限の日か達成した日を迎えた）")
        .with(
          { status: "maintenance" },
          ({ isWithinBand }) =>
            `体重の傾向が目標体重の ±${maintenanceBandKg} kg ${isWithinBand ? "に収まっている" : "を外れている"}`,
        )
        .exhaustive();

const renderWeeklyReview = (review: ReplyContextWeeklyReview): string[] => {
  const heading = `直近の週の見直し: ${formatDate(review.effectiveOn)}から。`;
  return match(review)
    .with({ type: "deferred" }, ({ reason }) => [
      `${heading}見送った（${match(reason)
        .with("within_first_week", () => "使い始めて1週に満たない")
        .with("no_weight", () => "体重の記録が無い")
        .with("few_meal_records", () => "食事の記録が少ない")
        .exhaustive()}）。1日の目安と推定消費カロリーは前の週のまま`,
    ])
    .with(
      { type: "reviewed" },
      ({ dailyGuideChangeKcal, expenditureChangeKcal, mainReason, limitHits }) => [
        `${heading}前の週から1日の目安 ${formatKcalChange(dailyGuideChangeKcal)}、推定消費カロリー ${formatKcalChange(expenditureChangeKcal)}`,
        `  主な理由: ${match(mainReason)
          .with("expenditure_change", () => "推定消費カロリーの変化")
          .with("balance_change", () => "1日に減らす（足す）分の変化")
          .exhaustive()}`,
        `  当たった上限と下限: ${
          limitHits.length === 0
            ? "なし"
            : limitHits
                .map((limitHit) =>
                  match(limitHit)
                    .with("weekly_change", () => "前の週からの変化の上限（±150 kcal）")
                    .with("required_pace", () => "必要な速さの上限")
                    .with("minimum_energy", () => "1日の目安の下限")
                    .exhaustive(),
                )
                .join("、")
        }`,
      ],
    )
    .exhaustive();
};

const formatKcalChange = (kcal: number): string => {
  const rounded = Math.round(kcal);
  return `${rounded === 0 ? "±" : rounded > 0 ? "+" : ""}${rounded} kcal`;
};

const formatNutrients = ({ energyKcal, proteinG, fatG, carbohydrateG }: MainNutrients): string =>
  [
    formatAmount(energyKcal, "", " kcal", 0),
    formatAmount(proteinG, "P ", " g", 1),
    formatAmount(fatG, "F ", " g", 1),
    formatAmount(carbohydrateG, "C ", " g", 1),
  ].join("、");

const formatAmount = (
  amount: NutrientAmount,
  label: string,
  unit: string,
  fractionDigits: number,
): string =>
  match(amount)
    .with(
      { type: "exactly" },
      ({ value }) => `${label}${formatNumber(value, fractionDigits)}${unit}`,
    )
    .with(
      { type: "at_least" },
      ({ value }) => `${label}${formatNumber(value, fractionDigits)}${unit} 以上`,
    )
    .with({ type: "unknown" }, () => `${label}不明`)
    .exhaustive();

// 小数は fractionDigits 桁で丸め、末尾の 0 を書かない
const formatNumber = (value: number, fractionDigits: number): string =>
  String(Number(value.toFixed(fractionDigits)));

const formatDishNames = (dishNames: readonly string[]): string =>
  dishNames.length === 0 ? "料理なし" : dishNames.join("、");

// YYYY-MM-DDTHH:mm の壁時計を「10/10(土) 12:40」に
const formatDateTime = (wallClock: string): string =>
  `${formatDate(wallClock.slice(0, "YYYY-MM-DD".length))} ${formatTime(wallClock)}`;

const formatDate = (calendarDay: string): string => {
  const dayOfWeekNames: Readonly<Record<DayOfWeek, string>> = {
    sunday: "日",
    monday: "月",
    tuesday: "火",
    wednesday: "水",
    thursday: "木",
    friday: "金",
    saturday: "土",
  };
  return `${calendarDay.slice(5, 7)}/${calendarDay.slice(8, 10)}(${dayOfWeekNames[computeDayOfWeek(calendarDay)]})`;
};

const formatTime = (wallClock: string): string => wallClock.slice("YYYY-MM-DDT".length);
