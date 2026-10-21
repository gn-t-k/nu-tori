import type { DailyGuide } from "../../../daily-guide/domain/daily-guide";
import type { Dish } from "../../../dish/domain/dish";
import { generateRecordId, type RecordId, recordIdSchema } from "../../../domain/record-id";
import type { ExpenditureEstimate } from "../../../expenditure-estimate/domain/expenditure-estimate";
import type { Goal } from "../../../goal/domain/goal";
import type { Ingredient, NewIngredient } from "../../../ingredient/domain/ingredient";
import type { Meal } from "../../../meal/domain/meal";
import type { SentText } from "../../../sent-text/domain/sent-text";
import type { WeeklyReview } from "../../../weekly-review/domain/weekly-review";
import type { WeightRecord } from "../../../weight-record/domain/weight-record";
import type { MealEstimationProgress } from "../../domain/reply-context";

// 返事の文脈を組み立てるテストで、アカウントに置く記録を作る。ID は末尾の数で見分ける
export const buildReplyContextRecords = {
  id: (n: number): RecordId =>
    recordIdSchema.parse(`00000000-0000-4000-8000-${n.toString().padStart(12, "0")}`),

  records: (
    overrides: Partial<ReplyContextRecords> & Pick<ReplyContextRecords, "sentText">,
  ): ReplyContextRecords => ({
    sentTexts: [],
    meals: [],
    weightRecords: [],
    goals: [],
    dailyGuides: [],
    expenditureEstimates: [],
    weeklyReviews: [],
    ...overrides,
  }),

  sentText: (n: number, sentAt: string, body = `文章${n}`): SentText => ({
    id: buildReplyContextRecords.id(n),
    body,
    sentAt: new Date(sentAt),
    timeZone: "Asia/Tokyo",
  }),

  // 会話と読み分け、返事の依頼がある送った文章。reply を渡すと返事もある
  conversation: (n: number, sentAt: string, reply?: string): RecordedSentText => ({
    sentText: buildReplyContextRecords.sentText(n, sentAt),
    classification: { type: "conversation", replyBody: reply },
  }),

  // 食事と読み分けた送った文章。返事の依頼は無い
  mealText: (n: number, sentAt: string, body: string): RecordedSentText => ({
    sentText: buildReplyContextRecords.sentText(n, sentAt, body),
    classification: { type: "meal" },
  }),

  // 推定の済んだ食事。時刻は東京（+09:00）で食べ、送った時刻は食べた時刻と同じ
  meal: (
    n: number,
    eatenAt: string,
    dishes: readonly RecordedDish[] = [],
    sentAt = eatenAt,
  ): RecordedMeal => ({
    meal: {
      id: buildReplyContextRecords.id(n),
      eatenAt: new Date(eatenAt),
      eatenAtUtcOffsetSeconds: 9 * 60 * 60,
      sentAt: new Date(sentAt),
      sentTimeZone: "Asia/Tokyo",
      entryMethod: "captured",
      photoIds: [buildReplyContextRecords.id(n + 5000)],
      sentTextId: undefined,
    },
    estimation: "settled",
    dishes,
  }),

  // 推定した料理。量は推定した量
  dish: (
    name: string,
    ingredients: readonly RecordedIngredient[],
    quantity: { quantity: number; unit: string } = { quantity: 1, unit: "杯" },
  ): RecordedDish => ({ id: generateRecordId(), name, estimatedQuantity: quantity, ingredients }),

  // 成分表の材料。量は g で、栄養は可食部 100 g あたり
  ingredient: (
    name: string,
    grams: number,
    nutrients: Ingredient["nutrients"],
  ): RecordedIngredient => ({
    id: generateRecordId(),
    name,
    quantity: grams,
    unit: "g",
    edibleGramsPerUnit: 1,
    nutrientSource: { type: "food_composition", foodNumber: "11221" },
    nutrients,
  }),

  weightRecord: (
    n: number,
    measuredAt: string,
    weightKg: number,
    imported?: WeightRecord["imported"],
  ): WeightRecord => ({
    id: buildReplyContextRecords.id(n),
    weightKg,
    measuredAt: new Date(measuredAt),
    timeZone: "Asia/Tokyo",
    version: 1,
    imported,
  }),

  // その日（東京）の 9:00 に量った体重記録
  weightRecordOn: (n: number, calendarDay: string, weightKg: number): WeightRecord =>
    buildReplyContextRecords.weightRecord(n, `${calendarDay}T00:00:00Z`, weightKg),

  // 目標。開始の日の体重の傾向は 72 kg で、決めた時刻は開始の日の 12:00（東京）。
  // 閉じた目標の終わった日は、置き場が次の目標の開始の日から出す
  goal: (
    n: number,
    startedOn: string,
    {
      targetWeightKg,
      weightChange,
      achievement,
      closure,
    }: Pick<Goal, "targetWeightKg" | "weightChange"> &
      Partial<Pick<Goal, "achievement" | "closure">>,
  ): Goal => ({
    id: buildReplyContextRecords.id(n),
    startedOn,
    startingWeightTrendKg: 72,
    targetWeightKg,
    decidedAt: new Date(`${startedOn}T03:00:00Z`),
    timeZone: "Asia/Tokyo",
    weightChange,
    achievement,
    deadlineConfirmation: undefined,
    closure,
  }),

  // 1日の目安。P・F・C は 105・55・270 g
  dailyGuide: (
    n: number,
    { goalId, expenditureEstimateId }: Pick<DailyGuide, "goalId" | "expenditureEstimateId">,
    effectiveOn: string,
    energyKcal: number,
    limitHits: DailyGuide["limitHits"] = [],
  ): DailyGuide => ({
    id: buildReplyContextRecords.id(n),
    goalId,
    expenditureEstimateId,
    effectiveOn,
    energyKcal,
    proteinG: 105,
    fatG: 55,
    carbohydrateG: 270,
    limitHits,
  }),

  expenditureEstimate: (
    n: number,
    effectiveOn: string,
    expenditureKcal: number,
  ): ExpenditureEstimate => ({
    id: buildReplyContextRecords.id(n),
    effectiveOn,
    expenditureKcal,
    estimatedAt: new Date(`${effectiveOn}T03:00:00Z`),
    initialSource: undefined,
  }),

  // 週の見直し。見直した時刻は当てる月曜の 9:00（東京）
  weeklyReview: (
    n: number,
    effectiveOn: string,
    outcome: WeeklyReview["outcome"],
  ): WeeklyReview => ({
    id: buildReplyContextRecords.id(n),
    effectiveOn,
    reviewedAt: new Date(`${effectiveOn}T00:00:00Z`),
    timeZone: "Asia/Tokyo",
    outcome,
  }),
};

type ReplyContextRecords = {
  // 応える文章。会話と読み分け、返事の依頼がある
  sentText: SentText;
  sentTexts: readonly RecordedSentText[];
  meals: readonly RecordedMeal[];
  weightRecords: readonly WeightRecord[];
  goals: readonly Goal[];
  dailyGuides: readonly DailyGuide[];
  expenditureEstimates: readonly ExpenditureEstimate[];
  weeklyReviews: readonly WeeklyReview[];
};

type RecordedSentText = {
  sentText: SentText;
  classification: { type: "conversation"; replyBody: string | undefined } | { type: "meal" };
};

// 食事と、その推定の進み。料理は推定の済んだ食事だけが持つ
type RecordedMeal = {
  meal: Meal;
  estimation: MealEstimationProgress;
  dishes: readonly RecordedDish[];
};

type RecordedDish = Pick<Dish, "id" | "name"> & {
  estimatedQuantity: { quantity: number; unit: string };
  ingredients: readonly RecordedIngredient[];
};

type RecordedIngredient = Omit<NewIngredient, "dishId" | "estimationId" | "positionInDish">;
