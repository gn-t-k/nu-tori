import type { RecordId } from "../../domain/record-id";
import type { NutrientAmount } from "../../ingredient/domain/nutrient-amount";
import type { MealEstimationProgress } from "./reply-context-source";

// 返事を作るときに AI に渡す文脈。並べる順は、変わらない指示 → 文脈の窓 → 構造化した値 → 新しい発言（キャッシュが効く順）。
// 時刻は、食事の時刻を除き、応える送った文章のタイムゾーンの壁時計（YYYY-MM-DDTHH:mm）。食事の時刻は食事の時差の壁時計
export type ReplyContext = {
  window: readonly ReplyContextWindowEntry[];
  structuredValues: ReplyContextStructuredValues;
  newUtterance: { at: string; body: string };
};

// 文脈の窓の1行。発言と、そのあいだに入った記録の印
export type ReplyContextWindowEntry =
  | { type: "user_utterance"; at: string; body: string }
  | { type: "ai_utterance"; at: string; body: string }
  | {
      type: "meal_recorded";
      at: string;
      mealId: RecordId;
      eatenAt: string;
      dishNames: readonly string[];
    }
  | { type: "weight_recorded"; at: string; weightKg: number };

export type ReplyContextStructuredValues = {
  // 送った文章の日時と曜日。今日は、この日時の日
  sentAt: { at: string; dayOfWeek: DayOfWeek };
  todayMeals: readonly {
    mealId: RecordId;
    eatenAt: string;
    estimation: MealEstimationProgress;
    dishes: readonly ReplyContextDish[];
  }[];
  yesterdayMeals: readonly { mealId: RecordId; eatenAt: string; dishNames: readonly string[] }[];
  // 今日の前の 7 日。古い日から並ぶ。推定を待つ・推定できなかった食事のある日は、分かる値が「以上」になる
  previousDays: readonly (
    | { calendarDay: string; recorded: false }
    | { calendarDay: string; recorded: true; nutrients: MainNutrients }
  )[];
  // 今日までの 28 日を 7 日ずつに分けた週ごとの、週の中で最後の傾向の値。古い週から並ぶ
  weeklyWeightTrend: readonly { firstDay: string; lastDay: string; trendKg: number | undefined }[];
  lastWeightRecord: { at: string; weightKg: number } | undefined;
};

export type ReplyContextDish = {
  name: string;
  quantity: { value: number; unit: string } | undefined;
  nutrients: MainNutrients;
};

export type MainNutrients = {
  energyKcal: NutrientAmount;
  proteinG: NutrientAmount;
  fatG: NutrientAmount;
  carbohydrateG: NutrientAmount;
};

export type DayOfWeek = "月" | "火" | "水" | "木" | "金" | "土" | "日";
