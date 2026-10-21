import type { AiUtterance } from "../../../ai-utterance/domain/ai-utterance";
import type { DailyGuide } from "../../../daily-guide/domain/daily-guide";
import type { Dish } from "../../../dish/domain/dish";
import type { ExpenditureEstimate } from "../../../expenditure-estimate/domain/expenditure-estimate";
import type { Goal } from "../../../goal/domain/goal";
import type { Ingredient } from "../../../ingredient/domain/ingredient";
import type { Meal } from "../../../meal/domain/meal";
import type { WeeklyReview } from "../../../weekly-review/domain/weekly-review";
import type { SentText } from "../../../sent-text/domain/sent-text";
import type { WeightRecord } from "../../../weight-record/domain/weight-record";
import type { WeightTrend } from "../../../weight-trend/domain/weight-trend";
import type { MealEstimationProgress } from "../reply-context";

// 返事に渡す文脈を組み立てる元の記録（buildReplyContext の中だけで使う）。組み立てる側が範囲で絞るので、読む側は多めに渡してよい。
// 要るのは、応える文章の窓の時間の前からの送った文章・食事・体重記録、応える文章の日の前の日の始まりからの食事、最後の体重記録、体重の傾向、
// 応える文章の日を含む目標とその1日の目安、その日以前の推定消費カロリーと、その日以前に当てた最も新しい週の見直し
export type ReplyContextSource = {
  // 応える送った文章
  sentText: SentText;
  // ほかの送った文章。食事と読み分けたまま（返事の依頼が無い）か、読み分け待ちなら replyRequest を持たない
  sentTexts: readonly {
    sentText: SentText;
    replyRequest: { aiUtterance: AiUtterance | undefined } | undefined;
  }[];
  meals: readonly ReplyContextSourceMeal[];
  weightRecords: readonly WeightRecord[];
  weightTrend: WeightTrend;
  // 体重記録のある日（記録のタイムゾーンでの YYYY-MM-DD）。ペースに使う
  weightRecordDays: readonly string[];
  goals: readonly Goal[];
  dailyGuides: readonly DailyGuide[];
  expenditureEstimates: readonly ExpenditureEstimate[];
  // 応える文章の日以前に当てた最も新しい週の見直し（見送りを含む）。まだ1週も見直していなければ無い
  latestWeeklyReview: WeeklyReview | undefined;
};

export type ReplyContextSourceMeal = {
  meal: Meal;
  // 栄養が出そろっているか。待っている（食事の推定か、料理の推定し直しを待つ）・推定できなかった食事の栄養は、合計に足りない
  estimation: MealEstimationProgress;
  dishes: readonly { dish: Dish; ingredients: readonly Ingredient[] }[];
};
