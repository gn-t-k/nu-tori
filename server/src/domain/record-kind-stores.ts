import type { AccountSettingsStore } from "../account-settings/domain/account-settings-store";
import type { DishStore } from "../dish/domain/dish-store";
import type { EstimationScheduleStore } from "../estimation/domain/estimation-schedule-store";
import type { EstimationStore } from "../estimation/domain/estimation-store";
import type { IngredientStore } from "../ingredient/domain/ingredient-store";
import type { MealPhotoStore } from "../meal/domain/meal-photo-store";
import type { MealStore } from "../meal/domain/meal-store";
import type { MealEstimationStatusStore } from "../meal-estimation-status/domain/meal-estimation-status-store";
import type { FirstSignInStore } from "./record-first-sign-in";
import type { WeightRecordStore } from "../weight-record/domain/weight-record-store";

// 登録簿の種類が使う置き場。種類を足すときは、種類の名前の順に1つずつ足す
export type RecordKindStores = {
  accountSettings: AccountSettingsStore;
  dish: DishStore;
  ingredient: IngredientStore;
  meal: MealStore;
  mealEstimationStatus: MealEstimationStatusStore;
  weightRecord: WeightRecordStore;
  // 使い始めた日を読むために、体重記録の種類と応答の startedOn が使う
  firstSignIn: FirstSignInStore;
  // 食事の写真がそろったかを見て、推定の予定に入れるために、食事の種類と写真の要求が使う
  mealPhoto: MealPhotoStore;
  estimationSchedule: EstimationScheduleStore;
  // 予定から推定を始め、試みと結果を書くために、アラームと食事の削除が使う
  estimation: EstimationStore;
};
