import type {
  DailyGuideLimitType,
  DailyGuideMainReason,
} from "../../daily-guide/domain/daily-guide";
import type { DailyGuideAmounts } from "../../daily-guide/domain/daily-guide-amounts";
import type { DayOfWeek } from "../../domain/day-of-week";
import type { RecordId } from "../../domain/record-id";
import type { Pace } from "../../goal/domain/compute-pace";
import type { GoalDirection } from "../../goal/domain/goal-direction";
import type { NutrientAmount } from "../../ingredient/domain/nutrient-amount";
import type { WeeklyReviewDeferralReason } from "../../weekly-review/domain/weekly-review";

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
  // 今日の食事の合計。今日の食事が無ければ無い。推定を待つ・推定できなかった食事があれば、分かる値が「以上」になる
  todayNutrients: MainNutrients | undefined;
  yesterdayMeals: readonly { mealId: RecordId; eatenAt: string; dishNames: readonly string[] }[];
  // 今日の前の 7 日。古い日から並ぶ。推定を待つ・推定できなかった食事のある日は、分かる値が「以上」になる
  previousDays: readonly (
    | { calendarDay: string; recorded: false }
    | { calendarDay: string; recorded: true; nutrients: MainNutrients }
  )[];
  // 今日までの 28 日を 7 日ずつに分けた週ごとの、週の中で最後の傾向の値。古い週から並ぶ
  weeklyWeightTrend: readonly { firstDay: string; lastDay: string; trendKg: number | undefined }[];
  lastWeightRecord: { at: string; weightKg: number } | undefined;
  // 今日を含む目標と、今日の1日の目安・推定消費カロリー。今日を含む目標が無ければ（目標を立てる前の日は）無い
  goal: ReplyContextGoal | undefined;
};

export type ReplyContextGoal = {
  direction: GoalDirection;
  // 期限（YYYY-MM-DD）。維持の目標には無い
  deadlineOn: string | undefined;
  targetWeightKg: number;
  dailyGuide: DailyGuideAmounts | undefined;
  // 今日以前で当てる始まりの日が最も遅い推定
  expenditureKcal: number | undefined;
  // この目標の、今日以前に当てた直近の見直し（見送りを含む）。まだ見直していなければ無い
  latestWeeklyReview: ReplyContextWeeklyReview | undefined;
  // 今日で判定したペース。目標の開始の日以前の体重の傾向が無ければ（体重記録を消したなど）出さない
  pace: Pace | undefined;
};

// 見直しの月曜（新しい1日の目安を当てる日。YYYY-MM-DD）と結果。見送った週は、1日の目安も推定消費カロリーも前の週のまま
export type ReplyContextWeeklyReview =
  | { type: "deferred"; effectiveOn: string; reason: WeeklyReviewDeferralReason }
  | {
      type: "reviewed";
      effectiveOn: string;
      limitHits: readonly DailyGuideLimitType[];
      mainReason: DailyGuideMainReason;
      // 前の週（月曜の前の日）に当たっていた値からの変化
      dailyGuideChangeKcal: number;
      expenditureChangeKcal: number;
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

// 食事の栄養が出そろったか（settled）、推定を待つか（awaiting）、推定できなかったか（failed）
export type MealEstimationProgress = "awaiting" | "failed" | "settled";
