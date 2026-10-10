import { addDays } from "../../../domain/add-days";
import { computeCalendarDay } from "../../../domain/compute-calendar-day";
import { computeCalendarDayInTimeZone } from "../../../domain/compute-calendar-day-in-time-zone";
import { computeUtcOffsetSeconds } from "../../../domain/compute-utc-offset-seconds";
import { computeNutrientTotal } from "../../../ingredient/domain/compute-nutrient-total";
import type { Ingredient } from "../../../ingredient/domain/ingredient";
import type { NutrientAmount } from "../../../ingredient/domain/nutrient-amount";
import type { Meal } from "../../../meal/domain/meal";
import { computeDayOfWeek } from "../compute-day-of-week";
import type {
  MainNutrients,
  ReplyContext,
  ReplyContextStructuredValues,
  ReplyContextWindowEntry,
} from "../reply-context";
import type { ReplyContextSource, ReplyContextSourceMeal } from "../reply-context-source";

// 返事を作るときに AI に渡す文脈を組み立てる。今日は、応える送った文章の時刻とタイムゾーンでの日
// （電波がなくてあとで届いた文章でも、送ったときの日で読む）
export const assembleReplyContext = (source: ReplyContextSource): ReplyContext => {
  const { sentText } = source;
  const toWallClock = (instant: Date): string =>
    formatWallClock(instant, computeUtcOffsetSeconds(instant, sentText.timeZone));
  // 応える文章より後に入った記録は、文章を送ったときに無かったので渡さない
  const sentByThen = (instant: Date): boolean => instant.getTime() <= sentText.sentAt.getTime();
  const meals = source.meals.filter(({ meal }) => sentByThen(meal.sentAt));
  return {
    window: assembleWindow({ ...source, meals }, toWallClock),
    structuredValues: assembleStructuredValues(
      {
        ...source,
        meals,
        weightRecords: source.weightRecords.filter(({ measuredAt }) => sentByThen(measuredAt)),
      },
      toWallClock,
    ),
    newUtterance: { at: toWallClock(sentText.sentAt), body: sentText.body },
  };
};

// 窓に入れる発言の数と時間。始まりは段で動かし、末尾にだけ足していく（キャッシュを効かせるため）
const maximumWindowUtterances = 20;
const windowUtteranceStep = 10;
const windowMilliseconds = 72 * 60 * 60 * 1000;
const windowStartStepMilliseconds = 6 * 60 * 60 * 1000;

const assembleWindow = (
  { sentText, sentTexts, meals, weightRecords }: ReplyContextSource,
  toWallClock: (instant: Date) => string,
): ReplyContextWindowEntry[] => {
  // 72 時間前を、6 時間の区切りに切り上げた時刻から。窓は 66〜72 時間になる
  const earliest =
    Math.ceil((sentText.sentAt.getTime() - windowMilliseconds) / windowStartStepMilliseconds) *
    windowStartStepMilliseconds;
  const isInWindowTime = (instant: Date): boolean =>
    instant.getTime() >= earliest && instant.getTime() <= sentText.sentAt.getTime();

  const utterances = sentTexts
    .filter(
      (other) =>
        other.sentText.id !== sentText.id &&
        other.replyRequest !== undefined &&
        isInWindowTime(other.sentText.sentAt),
    )
    .toSorted(
      (a, b) =>
        a.sentText.sentAt.getTime() - b.sentText.sentAt.getTime() ||
        a.sentText.id.localeCompare(b.sentText.id),
    )
    .flatMap(({ sentText: other, replyRequest }) => {
      const at = other.sentAt;
      const aiUtterance = replyRequest?.aiUtterance;
      return [
        { at, entry: { type: "user_utterance", at: toWallClock(at), body: other.body } as const },
        ...(aiUtterance === undefined
          ? []
          : [
              {
                at,
                entry: {
                  type: "ai_utterance",
                  at: toWallClock(at),
                  body: aiUtterance.body,
                } as const,
              },
            ]),
      ];
    });
  // 20 を超えたら、10 ずつ始まりを進める。窓は 11〜20 発言になる
  const start =
    utterances.length <= maximumWindowUtterances
      ? 0
      : Math.ceil((utterances.length - maximumWindowUtterances) / windowUtteranceStep) *
        windowUtteranceStep;
  const windowUtterances = utterances.slice(start);
  const first = windowUtterances[0];
  if (first === undefined) {
    return [];
  }
  const isBetweenUtterances = (instant: Date): boolean =>
    instant.getTime() >= first.at.getTime() && instant.getTime() <= sentText.sentAt.getTime();

  const records = [
    ...meals
      .filter(({ meal }) => isBetweenUtterances(meal.sentAt))
      .map(({ meal, dishes }) => ({
        at: meal.sentAt,
        entry: {
          type: "meal_recorded",
          at: toWallClock(meal.sentAt),
          mealId: meal.id,
          eatenAt: formatEatenAt(meal),
          dishNames: dishes.map(({ dish }) => dish.name),
        } as const,
      })),
    // ヘルスケアから取り込んだ体重は、使う人が入れた記録ではないので印にしない
    ...weightRecords
      .filter(
        ({ measuredAt, imported }) => imported === undefined && isBetweenUtterances(measuredAt),
      )
      .map(({ measuredAt, weightKg }) => ({
        at: measuredAt,
        entry: { type: "weight_recorded", at: toWallClock(measuredAt), weightKg } as const,
      })),
  ].toSorted((a, b) => a.at.getTime() - b.at.getTime());

  // 同じ時刻なら発言を先に置く（toSorted は安定）
  return [...windowUtterances, ...records]
    .toSorted((a, b) => a.at.getTime() - b.at.getTime())
    .map(({ entry }) => entry);
};

const assembleStructuredValues = (
  { sentText, meals, weightRecords, weightTrend }: ReplyContextSource,
  toWallClock: (instant: Date) => string,
): ReplyContextStructuredValues => {
  const today = computeCalendarDayInTimeZone(sentText.sentAt, sentText.timeZone);
  const yesterday = addDays(today, -1);
  const mealsOn = (calendarDay: string): readonly ReplyContextSourceMeal[] =>
    meals
      .filter(
        ({ meal }) =>
          computeCalendarDay(meal.eatenAt, meal.eatenAtUtcOffsetSeconds) === calendarDay,
      )
      .toSorted((a, b) => a.meal.eatenAt.getTime() - b.meal.eatenAt.getTime());

  const lastWeightRecord = weightRecords
    .toSorted((a, b) => a.measuredAt.getTime() - b.measuredAt.getTime())
    .at(-1);

  return {
    sentAt: { at: toWallClock(sentText.sentAt), dayOfWeek: computeDayOfWeek(today) },
    todayMeals: mealsOn(today).map(({ meal, estimation, dishes }) => ({
      mealId: meal.id,
      eatenAt: formatEatenAt(meal),
      estimation,
      dishes: dishes.map(({ dish, ingredients }) => ({
        name: dish.name,
        quantity:
          dish.quantity === undefined
            ? undefined
            : { value: dish.quantity.value, unit: dish.quantity.unit },
        nutrients: computeMainNutrients(ingredients),
      })),
    })),
    yesterdayMeals: mealsOn(yesterday).map(({ meal, dishes }) => ({
      mealId: meal.id,
      eatenAt: formatEatenAt(meal),
      dishNames: dishes.map(({ dish }) => dish.name),
    })),
    previousDays: Array.from({ length: 7 }, (_, index) => {
      const calendarDay = addDays(today, index - 7);
      const dayMeals = mealsOn(calendarDay);
      return dayMeals.length === 0
        ? { calendarDay, recorded: false as const }
        : {
            calendarDay,
            recorded: true as const,
            nutrients: computeDayNutrients(dayMeals),
          };
    }),
    weeklyWeightTrend: Array.from({ length: 4 }, (_, index) => {
      const firstDay = addDays(today, index * 7 - 27);
      const lastDay = addDays(firstDay, 6);
      return {
        firstDay,
        lastDay,
        trendKg: weightTrend
          .filter(({ calendarDay }) => calendarDay >= firstDay && calendarDay <= lastDay)
          .at(-1)?.trendKg,
      };
    }),
    lastWeightRecord:
      lastWeightRecord === undefined
        ? undefined
        : { at: toWallClock(lastWeightRecord.measuredAt), weightKg: lastWeightRecord.weightKg },
  };
};

const computeMainNutrients = (ingredients: readonly Ingredient[]): MainNutrients => ({
  energyKcal: computeNutrientTotal(ingredients, "energy_kcal"),
  proteinG: computeNutrientTotal(ingredients, "protein_g"),
  fatG: computeNutrientTotal(ingredients, "fat_g"),
  carbohydrateG: computeNutrientTotal(ingredients, "carbohydrate_g"),
});

const computeDayNutrients = (meals: readonly ReplyContextSourceMeal[]): MainNutrients => {
  const nutrients = computeMainNutrients(
    meals.flatMap(({ dishes }) => dishes.flatMap(({ ingredients }) => ingredients)),
  );
  if (meals.every(({ estimation }) => estimation === "settled")) {
    return nutrients;
  }
  return {
    energyKcal: markIncomplete(nutrients.energyKcal),
    proteinG: markIncomplete(nutrients.proteinG),
    fatG: markIncomplete(nutrients.fatG),
    carbohydrateG: markIncomplete(nutrients.carbohydrateG),
  };
};

// 栄養の分からない食事がほかにある合計にする。分かる値は「以上」に、分かる値の無い栄養は不明のまま
const markIncomplete = (amount: NutrientAmount): NutrientAmount =>
  amount.type === "exactly" ? { type: "at_least", value: amount.value } : amount;

const formatEatenAt = (meal: Meal): string =>
  formatWallClock(meal.eatenAt, meal.eatenAtUtcOffsetSeconds);

const formatWallClock = (instant: Date, utcOffsetSeconds: number): string =>
  new Date(instant.getTime() + utcOffsetSeconds * 1000)
    .toISOString()
    .slice(0, "YYYY-MM-DDTHH:mm".length);
