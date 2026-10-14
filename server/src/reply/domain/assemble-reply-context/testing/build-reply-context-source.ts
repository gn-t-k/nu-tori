import type { AiUtterance } from "../../../../ai-utterance/domain/ai-utterance";
import type { DailyGuide } from "../../../../daily-guide/domain/daily-guide";
import type { Dish } from "../../../../dish/domain/dish";
import { type RecordId, recordIdSchema } from "../../../../domain/record-id";
import type { ExpenditureEstimate } from "../../../../expenditure-estimate/domain/expenditure-estimate";
import type { Goal } from "../../../../goal/domain/goal";
import type { Ingredient } from "../../../../ingredient/domain/ingredient";
import type { SentText } from "../../../../sent-text/domain/sent-text";
import type { WeightRecord } from "../../../../weight-record/domain/weight-record";
import type { ReplyContextSource, ReplyContextSourceMeal } from "../../reply-context-source";

// 文脈の組み立てのテストの入力を作る。ID は末尾の数で見分ける
export const buildReplyContextSource = {
  id: (n: number): RecordId =>
    recordIdSchema.parse(`00000000-0000-4000-8000-${n.toString().padStart(12, "0")}`),

  source: (overrides: Partial<ReplyContextSource> & Pick<ReplyContextSource, "sentText">) => ({
    sentTexts: [],
    meals: [],
    weightRecords: [],
    weightTrend: [],
    goals: [],
    dailyGuides: [],
    expenditureEstimates: [],
    ...overrides,
  }),

  sentText: (n: number, sentAt: string, body = `文章${n}`): SentText => ({
    id: buildReplyContextSource.id(n),
    body,
    sentAt: new Date(sentAt),
    timeZone: "Asia/Tokyo",
  }),

  // 返事の依頼がある送った文章。reply を渡すと返事もある
  conversation: (
    n: number,
    sentAt: string,
    reply?: string,
  ): ReplyContextSource["sentTexts"][number] => ({
    sentText: buildReplyContextSource.sentText(n, sentAt),
    replyRequest: {
      aiUtterance:
        reply === undefined ? undefined : buildReplyContextSource.aiUtterance(n + 1000, n, reply),
    },
  }),

  aiUtterance: (n: number, sentTextN: number, body: string): AiUtterance => ({
    id: buildReplyContextSource.id(n),
    body,
    sentTextId: buildReplyContextSource.id(sentTextN),
    mealIds: [],
  }),

  // 食事。時刻は東京（+09:00）で食べ、送った時刻は食べた時刻と同じ
  meal: (
    n: number,
    eatenAt: string,
    dishes: ReplyContextSourceMeal["dishes"] = [],
    sentAt = eatenAt,
  ): ReplyContextSourceMeal => ({
    meal: {
      id: buildReplyContextSource.id(n),
      eatenAt: new Date(eatenAt),
      eatenAtUtcOffsetSeconds: 9 * 60 * 60,
      sentAt: new Date(sentAt),
      sentTimeZone: "Asia/Tokyo",
      entryMethod: "captured",
      photoIds: [buildReplyContextSource.id(n + 5000)],
      sentTextId: undefined,
    },
    estimation: "settled",
    dishes,
  }),

  dish: (
    name: string,
    ingredients: readonly Ingredient[],
    quantity: Dish["quantity"] = { value: 1, unit: "杯", source: "estimated" },
  ): ReplyContextSourceMeal["dishes"][number] => ({
    dish: {
      id: buildReplyContextSource.id(9000),
      mealId: buildReplyContextSource.id(9001),
      name,
      quantity,
      positionInMeal: 0,
      version: 1,
    },
    ingredients,
  }),

  // 成分表の材料。量は g で、栄養は可食部 100 g あたり
  ingredient: (name: string, grams: number, nutrients: Ingredient["nutrients"]): Ingredient => ({
    id: buildReplyContextSource.id(9100),
    dishId: buildReplyContextSource.id(9000),
    estimationId: "estimation",
    name,
    quantity: grams,
    quantitySource: "estimated",
    unit: "g",
    edibleGramsPerUnit: 1,
    positionInDish: 0,
    nutrientSource: { type: "food_composition", foodNumber: "11221" },
    nutrients,
  }),

  weightRecord: (
    n: number,
    measuredAt: string,
    weightKg: number,
    imported?: WeightRecord["imported"],
  ): WeightRecord => ({
    id: buildReplyContextSource.id(n),
    weightKg,
    measuredAt: new Date(measuredAt),
    timeZone: "Asia/Tokyo",
    version: 1,
    imported,
  }),

  // 目標。開始の日の体重の傾向は 72 kg で、決めた時刻は開始の日の 12:00（東京）
  goal: (
    n: number,
    startedOn: string,
    {
      targetWeightKg,
      weightChange,
      closure,
    }: Pick<Goal, "targetWeightKg" | "weightChange"> & Partial<Pick<Goal, "closure">>,
  ): Goal => ({
    id: buildReplyContextSource.id(n),
    startedOn,
    startingWeightTrendKg: 72,
    targetWeightKg,
    decidedAt: new Date(`${startedOn}T03:00:00Z`),
    timeZone: "Asia/Tokyo",
    weightChange,
    closure,
  }),

  // 1日の目安。P・F・C は 105・55・270 g
  dailyGuide: (
    n: number,
    goalId: RecordId,
    effectiveOn: string,
    energyKcal: number,
  ): DailyGuide => ({
    id: buildReplyContextSource.id(n),
    goalId,
    expenditureEstimateId: buildReplyContextSource.id(n + 100),
    effectiveOn,
    energyKcal,
    proteinG: 105,
    fatG: 55,
    carbohydrateG: 270,
    limitHits: [],
  }),

  expenditureEstimate: (
    n: number,
    effectiveOn: string,
    expenditureKcal: number,
  ): ExpenditureEstimate => ({
    id: buildReplyContextSource.id(n),
    effectiveOn,
    expenditureKcal,
    estimatedAt: new Date(`${effectiveOn}T03:00:00Z`),
    initialSource: undefined,
  }),
};
