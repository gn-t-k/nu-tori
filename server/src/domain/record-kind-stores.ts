import type { AccountSettingsStore } from "../account-settings/domain/account-settings-store";
import type { MealStore } from "../meal/domain/meal-store";
import type { MealEstimationStatusStore } from "../meal-estimation-status/domain/meal-estimation-status-store";
import type { FirstSignInStore } from "./record-first-sign-in";
import type { WeightRecordStore } from "../weight-record/domain/weight-record-store";

// 登録簿の種類が使う置き場。種類を足すときは、種類の名前の順に1つずつ足す
export type RecordKindStores = {
  accountSettings: AccountSettingsStore;
  meal: MealStore;
  mealEstimationStatus: MealEstimationStatusStore;
  weightRecord: WeightRecordStore;
  // 使い始めた日を読むために、体重記録の種類と応答の startedOn が使う
  firstSignIn: FirstSignInStore;
};
