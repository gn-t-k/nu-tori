import { drizzle } from "drizzle-orm/durable-sqlite";
import { createAccountSettingsStore } from "../account-settings/durable-object/create-account-settings-store";
import { createAiUtteranceStore } from "../ai-utterance/durable-object/create-ai-utterance-store";
import { createDishStore } from "../dish/durable-object/create-dish-store";
import { createDishEstimationStatusStore } from "../dish-estimation-status/durable-object/create-dish-estimation-status-store";
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
import { createSentTextStore } from "../sent-text/durable-object/create-sent-text-store";
import { createSentTextStatusStore } from "../sent-text-status/durable-object/create-sent-text-status-store";
import { createFirstSignInStore } from "./create-first-sign-in-store";
import { createLatestTimeZoneStore } from "./create-latest-time-zone-store";
import { createUsualWeighingTimeStore } from "../usual-weighing-time/durable-object/create-usual-weighing-time-store";
import { createWeightRecordStore } from "../weight-record/durable-object/create-weight-record-store";

// 登録簿の種類の置き場を作る。種類のまとまりの durable-object/ にある実装を、名前の順に1行ずつ足す
export const createRecordKindStores = (storage: DurableObjectStorage): RecordKindStores => {
  const db = drizzle(storage);
  const meal = createMealStore(db);
  const mealEstimationStatus = createMealEstimationStatusStore(db);
  const estimationEventWrite = createEstimationEventWriteStore(db);
  const dish = createDishStore(db);
  const dishEstimationStatus = createDishEstimationStatusStore(db);
  return {
    accountSettings: createAccountSettingsStore(db),
    aiUtterance: createAiUtteranceStore(db),
    dish,
    dishEstimationStatus,
    ingredient: createIngredientStore(db),
    meal,
    mealEstimationStatus,
    notice: createNoticeStore(db),
    sentText: createSentTextStore(db),
    sentTextStatus: createSentTextStatusStore(db),
    usualWeighingTime: createUsualWeighingTimeStore(db),
    weightRecord: createWeightRecordStore(db),
    firstSignIn: createFirstSignInStore(db),
    latestTimeZone: createLatestTimeZoneStore(db),
    mealPhoto: createMealPhotoStore(db),
    estimationSchedule: createEstimationScheduleStore(db),
    estimation: createEstimationStore(db),
    writeEstimationEvents: (addChange, now, run) =>
      writeEstimationEvents(
        { meal, mealEstimationStatus, dish, dishEstimationStatus, estimationEventWrite },
        addChange,
        now,
        run,
      ),
  };
};
