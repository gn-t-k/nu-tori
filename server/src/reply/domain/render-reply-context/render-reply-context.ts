import { match } from "ts-pattern";
import type { NutrientAmount } from "../../../ingredient/domain/nutrient-amount";
import { computeDayOfWeek } from "../compute-day-of-week";
import type {
  MainNutrients,
  ReplyContext,
  ReplyContextStructuredValues,
  ReplyContextWindowEntry,
} from "../reply-context";

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
  ].join("\n");

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

const formatDate = (calendarDay: string): string =>
  `${calendarDay.slice(5, 7)}/${calendarDay.slice(8, 10)}(${computeDayOfWeek(calendarDay)})`;

const formatTime = (wallClock: string): string => wallClock.slice("YYYY-MM-DDT".length);
