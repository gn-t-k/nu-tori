import { drizzle } from "drizzle-orm/durable-sqlite";
import { createAccountSettingsStore } from "../account-settings/durable-object/create-account-settings-store";
import { createAiUtteranceStore } from "../ai-utterance/durable-object/create-ai-utterance-store";
import { createDailyGuideStore } from "../daily-guide/durable-object/create-daily-guide-store";
import type { RecordKindStores } from "../domain/record-kind-stores";
import { createEstimationScheduleStore } from "../estimation/durable-object/create-estimation-schedule-store";
import { createEstimationStore } from "../estimation/durable-object/create-estimation-store";
import { writeEstimationEvents } from "../estimation/domain/write-estimation-events";
import { createExpenditureEstimateStore } from "../expenditure-estimate/durable-object/create-expenditure-estimate-store";
import { createGoalStore } from "../goal/durable-object/create-goal-store";
import { createIngredientStore } from "../ingredient/durable-object/create-ingredient-store";
import { createMealPhotoStore } from "../meal/durable-object/create-meal-photo-store";
import { createNoticeStore } from "../notice/durable-object/create-notice-store";
import { writeReplyEvents } from "../reply/domain/write-reply-events";
import { createReplyStore } from "../reply/durable-object/create-reply-store";
import { createEventWriteStores } from "./create-event-write-stores";
import { createFirstSignInStore } from "./create-first-sign-in-store";
import { createLatestTimeZoneStore } from "./create-latest-time-zone-store";
import { createUsualWeighingTimeStore } from "../usual-weighing-time/durable-object/create-usual-weighing-time-store";
import { createWeeklyReviewStore } from "../weekly-review/durable-object/create-weekly-review-store";
import { createWeightRecordStore } from "../weight-record/durable-object/create-weight-record-store";

// 登録簿の種類の置き場を作る。種類のまとまりの durable-object/ にある実装を、名前の順に1行ずつ足す
export const createRecordKindStores = (storage: DurableObjectStorage): RecordKindStores => {
  const db = drizzle(storage);
  const {
    meal,
    mealEstimationStatus,
    estimationEventWrite,
    dish,
    dishEstimationStatus,
    sentText,
    sentTextStatus,
    replyEventWrite,
  } = createEventWriteStores(db);
  return {
    accountSettings: createAccountSettingsStore(db),
    aiUtterance: createAiUtteranceStore(db),
    dailyGuide: createDailyGuideStore(db),
    dish,
    dishEstimationStatus,
    expenditureEstimate: createExpenditureEstimateStore(db),
    goal: createGoalStore(db),
    ingredient: createIngredientStore(db),
    meal,
    mealEstimationStatus,
    notice: createNoticeStore(db),
    sentText,
    sentTextStatus,
    usualWeighingTime: createUsualWeighingTimeStore(db),
    weeklyReview: createWeeklyReviewStore(db),
    weightRecord: createWeightRecordStore(db),
    firstSignIn: createFirstSignInStore(db),
    latestTimeZone: createLatestTimeZoneStore(db),
    mealPhoto: createMealPhotoStore(db),
    estimationSchedule: createEstimationScheduleStore(db),
    estimation: createEstimationStore(db),
    reply: createReplyStore(db),
    writeEstimationEvents: (addChange, now, run) =>
      writeEstimationEvents(
        { meal, mealEstimationStatus, dish, dishEstimationStatus, estimationEventWrite },
        addChange,
        now,
        run,
      ),
    writeReplyEvents: (addChange, run) =>
      writeReplyEvents({ sentText, sentTextStatus, replyEventWrite }, addChange, run),
  };
};
