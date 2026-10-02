import { drizzle } from "drizzle-orm/durable-sqlite";
import { createAccountSettingsStore } from "../account-settings/durable-object/create-account-settings-store";
import { createDishStore } from "../dish/durable-object/create-dish-store";
import type { RecordKindStores } from "../domain/record-kind-stores";
import { createEstimationEventWriteStore } from "../estimation/durable-object/create-estimation-event-write-store";
import { createEstimationScheduleStore } from "../estimation/durable-object/create-estimation-schedule-store";
import { createEstimationStore } from "../estimation/durable-object/create-estimation-store";
import { writeEstimationEvents } from "../estimation/domain/write-estimation-events";
import { createIngredientStore } from "../ingredient/durable-object/create-ingredient-store";
import { createMealPhotoStore } from "../meal/durable-object/create-meal-photo-store";
import { createMealStore } from "../meal/durable-object/create-meal-store";
import { createMealEstimationStatusStore } from "../meal-estimation-status/durable-object/create-meal-estimation-status-store";
import { createNoticeStore } from "../notice/durable-object/create-notice-store";
import { createFirstSignInStore } from "./create-first-sign-in-store";
import { createWeightRecordStore } from "../weight-record/durable-object/create-weight-record-store";

// 登録簿の種類の置き場を作る。種類のまとまりの durable-object/ にある実装を、名前の順に1行ずつ足す
export const createRecordKindStores = (storage: DurableObjectStorage): RecordKindStores => {
  const db = drizzle(storage);
  const meal = createMealStore(db);
  const mealEstimationStatus = createMealEstimationStatusStore(db);
  const estimationEventWrite = createEstimationEventWriteStore(db);
  return {
    accountSettings: createAccountSettingsStore(db),
    dish: createDishStore(db),
    ingredient: createIngredientStore(db),
    meal,
    mealEstimationStatus,
    notice: createNoticeStore(db),
    weightRecord: createWeightRecordStore(db),
    firstSignIn: createFirstSignInStore(db),
    mealPhoto: createMealPhotoStore(db),
    estimationSchedule: createEstimationScheduleStore(db),
    estimation: createEstimationStore(db),
    writeEstimationEvents: (addChange, run) =>
      writeEstimationEvents({ meal, mealEstimationStatus, estimationEventWrite }, addChange, run),
  };
};
