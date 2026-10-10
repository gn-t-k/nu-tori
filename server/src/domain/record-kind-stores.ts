import type { AccountSettingsStore } from "../account-settings/domain/account-settings-store";
import type { AiUtteranceStore } from "../ai-utterance/domain/ai-utterance-store";
import type { DishStore } from "../dish/domain/dish-store";
import type { DishEstimationStatusStore } from "../dish-estimation-status/domain/dish-estimation-status-store";
import type { EstimationScheduleStore } from "../estimation/domain/estimation-schedule-store";
import type { EstimationStore } from "../estimation/domain/estimation-store";
import type { EstimationWrites } from "../estimation/domain/estimation-writes";
import type { IngredientStore } from "../ingredient/domain/ingredient-store";
import type { MealPhotoStore } from "../meal/domain/meal-photo-store";
import type { MealStore } from "../meal/domain/meal-store";
import type { MealEstimationStatusStore } from "../meal-estimation-status/domain/meal-estimation-status-store";
import type { NoticeStore } from "../notice/domain/notice-store";
import type { ReplyStore } from "../reply/domain/reply-store";
import type { ReplyWrites } from "../reply/domain/reply-writes";
import type { SentTextStore } from "../sent-text/domain/sent-text-store";
import type { SentTextStatusStore } from "../sent-text-status/domain/sent-text-status-store";
import type { LatestTimeZoneStore } from "./latest-time-zone-store";
import type { FirstSignInStore } from "./record-first-sign-in";
import type { UsualWeighingTimeStore } from "../usual-weighing-time/domain/usual-weighing-time-store";
import type { RecordChangeTarget } from "./sync-ledger/record-change-target";
import type { WeightRecordStore } from "../weight-record/domain/weight-record-store";

// 登録簿の種類が使う置き場。種類を足すときは、種類の名前の順に1つずつ足す
export type RecordKindStores = {
  accountSettings: AccountSettingsStore;
  aiUtterance: AiUtteranceStore;
  dish: DishStore;
  dishEstimationStatus: DishEstimationStatusStore;
  ingredient: IngredientStore;
  meal: MealStore;
  mealEstimationStatus: MealEstimationStatusStore;
  notice: NoticeStore;
  sentText: SentTextStore;
  sentTextStatus: SentTextStatusStore;
  usualWeighingTime: UsualWeighingTimeStore;
  weightRecord: WeightRecordStore;
  // 使い始めた日を読むために、体重記録の種類と応答の startedOn が使う
  firstSignIn: FirstSignInStore;
  // 日を決めるために、いつもの時刻の学び直しと、推定の数える日・見送りの次の日が使う
  latestTimeZone: LatestTimeZoneStore;
  // 食事の写真がそろったかを見て、推定の予定に入れるために、食事の種類と写真の要求が使う
  mealPhoto: MealPhotoStore;
  estimationSchedule: EstimationScheduleStore;
  // 推定と試みを読むために、アラームと食事の削除が使う
  estimation: EstimationStore;
  // 返事の流れを読むために、アラームと送った文章の状態が使う
  reply: ReplyStore;
  // 推定の予定と結果を書く口（ドメイン層の writeEstimationEvents に、書く置き場を渡したもの）。
  // 書く置き場はここにしか渡さないので、推定の予定と結果はこの口を通してしか書けない
  writeEstimationEvents: <T>(
    addChange: (
      change: RecordChangeTarget<"meal_estimation_status" | "dish_estimation_status">,
    ) => void,
    now: Date,
    run: (writes: EstimationWrites) => T,
  ) => T;
  // 返事の流れの出来事を書く口（ドメイン層の writeReplyEvents に、書く置き場を渡したもの）。
  // 書く置き場はここにしか渡さないので、返事の依頼から返事・作れなかったまでは、この口を通してしか書けない
  writeReplyEvents: <T>(
    addChange: (change: RecordChangeTarget<"sent_text_status" | "ai_utterance">) => void,
    run: (writes: ReplyWrites) => T,
  ) => T;
};
