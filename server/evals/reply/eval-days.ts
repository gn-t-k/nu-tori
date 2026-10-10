import { evalMealId } from "./eval-meal-id";
import type {
  MainNutrients,
  ReplyContext,
  ReplyContextDish,
} from "../../src/reply/domain/reply-context";

// 評価の組の文脈の元になる2日（作り話。公開リポジトリなので、開発者の記録は使わない）。
// どちらも東京の 2026-10-10（土）に送った発言に応える。場面は、この日に発言を差し替えて作る（cases.ts）

const nutrients = (
  energyKcal: number,
  proteinG: number,
  fatG: number,
  carbohydrateG: number,
): MainNutrients => ({
  energyKcal: { type: "exactly", value: energyKcal },
  proteinG: { type: "exactly", value: proteinG },
  fatG: { type: "exactly", value: fatG },
  carbohydrateG: { type: "exactly", value: carbohydrateG },
});

const dish = (
  name: string,
  value: number,
  unit: string,
  mainNutrients: MainNutrients,
): ReplyContextDish => ({ name, quantity: { value, unit }, nutrients: mainNutrients });

// 記録の多い日: 3日続けて朝・昼・夜を記録し、体重を毎朝量り、会話もしている人の、夕食のあと
const richDay: ReplyContext = {
  window: [
    {
      type: "user_utterance",
      at: "2026-10-07T21:05",
      body: "明日は会社の飲み会です。何に気をつければいいですか？",
    },
    {
      type: "ai_utterance",
      at: "2026-10-07T21:05",
      body: "飲み会では、最初に枝豆や冷ややっこ、サラダのような料理を頼むと、揚げ物や締めの量を抑えやすくなります。お酒の合間に水も飲むと、食べすぎを防げます。楽しんできてくださいね。",
    },
    {
      type: "meal_recorded",
      at: "2026-10-08T07:40",
      mealId: evalMealId(101),
      eatenAt: "2026-10-08T07:40",
      dishNames: ["トースト", "目玉焼き"],
    },
    {
      type: "meal_recorded",
      at: "2026-10-08T12:20",
      mealId: evalMealId(105),
      eatenAt: "2026-10-08T12:20",
      dishNames: ["ざるそば"],
    },
    {
      type: "meal_recorded",
      at: "2026-10-08T23:10",
      mealId: evalMealId(106),
      eatenAt: "2026-10-08T21:00",
      dishNames: ["唐揚げ", "ビール", "枝豆"],
    },
    { type: "user_utterance", at: "2026-10-08T23:15", body: "飲み会で食べすぎました…" },
    {
      type: "ai_utterance",
      at: "2026-10-08T23:15",
      body: "お疲れさまでした。1日多く食べても、体づくりは週の流れで見れば大丈夫です。明日はいつもどおりの食事に戻しましょう。",
    },
    {
      type: "meal_recorded",
      at: "2026-10-09T07:50",
      mealId: evalMealId(104),
      eatenAt: "2026-10-09T07:50",
      dishNames: ["ヨーグルト", "バナナ"],
    },
    { type: "weight_recorded", at: "2026-10-09T08:00", weightKg: 68.6 },
    {
      type: "meal_recorded",
      at: "2026-10-09T12:30",
      mealId: evalMealId(102),
      eatenAt: "2026-10-09T12:30",
      dishNames: ["親子丼"],
    },
    {
      type: "meal_recorded",
      at: "2026-10-09T19:30",
      mealId: evalMealId(103),
      eatenAt: "2026-10-09T19:30",
      dishNames: ["醤油ラーメン"],
    },
    { type: "weight_recorded", at: "2026-10-10T07:30", weightKg: 68.1 },
    {
      type: "meal_recorded",
      at: "2026-10-10T07:45",
      mealId: evalMealId(111),
      eatenAt: "2026-10-10T07:45",
      dishNames: ["納豆ごはん", "豆腐とわかめの味噌汁"],
    },
    {
      type: "meal_recorded",
      at: "2026-10-10T12:40",
      mealId: evalMealId(112),
      eatenAt: "2026-10-10T12:40",
      dishNames: ["鶏むね肉のサラダ", "鮭おにぎり"],
    },
    {
      type: "meal_recorded",
      at: "2026-10-10T15:20",
      mealId: evalMealId(113),
      eatenAt: "2026-10-10T15:20",
      dishNames: ["プロテインバー"],
    },
    {
      type: "meal_recorded",
      at: "2026-10-10T19:10",
      mealId: evalMealId(114),
      eatenAt: "2026-10-10T19:10",
      dishNames: ["鮭の塩焼き定食"],
    },
  ],
  structuredValues: {
    sentAt: { at: "2026-10-10T19:40", dayOfWeek: "saturday" },
    todayMeals: [
      {
        mealId: evalMealId(111),
        eatenAt: "2026-10-10T07:45",
        estimation: "settled",
        dishes: [
          dish("納豆ごはん", 1, "杯", nutrients(340, 12, 5, 60)),
          dish("豆腐とわかめの味噌汁", 1, "杯", nutrients(45, 3.5, 1.8, 4)),
        ],
      },
      {
        mealId: evalMealId(112),
        eatenAt: "2026-10-10T12:40",
        estimation: "settled",
        dishes: [
          dish("鶏むね肉のサラダ", 1, "皿", nutrients(210, 28, 7, 8)),
          dish("鮭おにぎり", 1, "個", nutrients(190, 6, 1.5, 38)),
        ],
      },
      {
        mealId: evalMealId(113),
        eatenAt: "2026-10-10T15:20",
        estimation: "settled",
        dishes: [dish("プロテインバー", 1, "本", nutrients(200, 15, 8, 18))],
      },
      {
        mealId: evalMealId(114),
        eatenAt: "2026-10-10T19:10",
        estimation: "settled",
        dishes: [dish("鮭の塩焼き定食", 1, "食", nutrients(680, 38, 18, 88))],
      },
    ],
    todayNutrients: nutrients(1665, 102.5, 41.3, 216),
    yesterdayMeals: [
      { mealId: evalMealId(104), eatenAt: "2026-10-09T07:50", dishNames: ["ヨーグルト", "バナナ"] },
      { mealId: evalMealId(102), eatenAt: "2026-10-09T12:30", dishNames: ["親子丼"] },
      { mealId: evalMealId(103), eatenAt: "2026-10-09T19:30", dishNames: ["醤油ラーメン"] },
    ],
    previousDays: [
      { calendarDay: "2026-10-03", recorded: true, nutrients: nutrients(2010, 92, 68, 250) },
      { calendarDay: "2026-10-04", recorded: true, nutrients: nutrients(2240, 85, 80, 280) },
      { calendarDay: "2026-10-05", recorded: true, nutrients: nutrients(1890, 101, 60, 230) },
      { calendarDay: "2026-10-06", recorded: true, nutrients: nutrients(1950, 96, 62, 240) },
      { calendarDay: "2026-10-07", recorded: true, nutrients: nutrients(2120, 88, 75, 265) },
      { calendarDay: "2026-10-08", recorded: true, nutrients: nutrients(2480, 90, 95, 300) },
      { calendarDay: "2026-10-09", recorded: true, nutrients: nutrients(1980, 79, 64, 262) },
    ],
    weeklyWeightTrend: [
      { firstDay: "2026-09-13", lastDay: "2026-09-19", trendKg: 69.6 },
      { firstDay: "2026-09-20", lastDay: "2026-09-26", trendKg: 69.2 },
      { firstDay: "2026-09-27", lastDay: "2026-10-03", trendKg: 68.8 },
      { firstDay: "2026-10-04", lastDay: "2026-10-10", trendKg: 68.3 },
    ],
    lastWeightRecord: { at: "2026-10-10T07:30", weightKg: 68.1 },
  },
  newUtterance: { at: "2026-10-10T19:40", body: "" },
};

// 記録の少ない日: ときどきしか記録しない人の、昼。今日はカフェラテだけ、会話は無い
const sparseDay: ReplyContext = {
  window: [
    {
      type: "meal_recorded",
      at: "2026-10-10T08:30",
      mealId: evalMealId(211),
      eatenAt: "2026-10-10T08:30",
      dishNames: ["カフェラテ"],
    },
  ],
  structuredValues: {
    sentAt: { at: "2026-10-10T12:15", dayOfWeek: "saturday" },
    todayMeals: [
      {
        mealId: evalMealId(211),
        eatenAt: "2026-10-10T08:30",
        estimation: "settled",
        dishes: [dish("カフェラテ", 1, "杯", nutrients(150, 6, 6, 17))],
      },
    ],
    todayNutrients: nutrients(150, 6, 6, 17),
    yesterdayMeals: [],
    previousDays: [
      { calendarDay: "2026-10-03", recorded: false },
      { calendarDay: "2026-10-04", recorded: false },
      { calendarDay: "2026-10-05", recorded: true, nutrients: nutrients(1820, 64, 58, 240) },
      { calendarDay: "2026-10-06", recorded: false },
      { calendarDay: "2026-10-07", recorded: false },
      { calendarDay: "2026-10-08", recorded: true, nutrients: nutrients(1540, 52, 50, 205) },
      { calendarDay: "2026-10-09", recorded: false },
    ],
    weeklyWeightTrend: [
      { firstDay: "2026-09-13", lastDay: "2026-09-19", trendKg: undefined },
      { firstDay: "2026-09-20", lastDay: "2026-09-26", trendKg: undefined },
      { firstDay: "2026-09-27", lastDay: "2026-10-03", trendKg: 72.5 },
      { firstDay: "2026-10-04", lastDay: "2026-10-10", trendKg: 72.3 },
    ],
    lastWeightRecord: { at: "2026-10-06T07:10", weightKg: 72.3 },
  },
  newUtterance: { at: "2026-10-10T12:15", body: "" },
};

// 今日まだ何も記録していない日（記録の少ない日から、今日の食事と窓を除いたもの）
const emptyToday: ReplyContext = {
  window: [],
  structuredValues: { ...sparseDay.structuredValues, todayMeals: [], todayNutrients: undefined },
  newUtterance: sparseDay.newUtterance,
};

export const evalDays = { richDay, sparseDay, emptyToday };
