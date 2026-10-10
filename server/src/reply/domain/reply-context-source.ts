import type { AiUtterance } from "../../ai-utterance/domain/ai-utterance";
import type { Dish } from "../../dish/domain/dish";
import type { Ingredient } from "../../ingredient/domain/ingredient";
import type { Meal } from "../../meal/domain/meal";
import type { SentText } from "../../sent-text/domain/sent-text";
import type { WeightRecord } from "../../weight-record/domain/weight-record";
import type { WeightTrend } from "../../weight-trend/domain/weight-trend";

// 返事に渡す文脈を組み立てる元の記録。組み立てる側が範囲で絞るので、読む側は多めに渡してよい。
// 要るのは、応える文章の 72 時間前からの送った文章・食事・体重記録、応える文章の日の 7 日前からの食事、最後の体重記録、体重の傾向
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
};

export type ReplyContextSourceMeal = {
  meal: Meal;
  // 栄養が出そろっているか。待っている（食事の推定か、料理の推定し直しを待つ）・推定できなかった食事の栄養は、合計に足りない
  estimation: MealEstimationProgress;
  dishes: readonly { dish: Dish; ingredients: readonly Ingredient[] }[];
};

export type MealEstimationProgress = "awaiting" | "failed" | "settled";
