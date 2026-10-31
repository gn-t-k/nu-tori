import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { createDishStore } from "../dish/durable-object/create-dish-store";
import { createDishEstimationStatusStore } from "../dish-estimation-status/durable-object/create-dish-estimation-status-store";
import { createEstimationEventWriteStore } from "../estimation/durable-object/create-estimation-event-write-store";
import { createEstimationScheduleStore } from "../estimation/durable-object/create-estimation-schedule-store";
import { createEstimationStore } from "../estimation/durable-object/create-estimation-store";
import { createMealStore } from "../meal/durable-object/create-meal-store";
import { createMealEstimationStatusStore } from "../meal-estimation-status/durable-object/create-meal-estimation-status-store";
import { createReplyEventWriteStore } from "../reply/durable-object/create-reply-event-write-store";
import { createSentTextStore } from "../sent-text/durable-object/create-sent-text-store";
import { createSentTextStatusStore } from "../sent-text-status/durable-object/create-sent-text-status-store";

// 推定と返事の流れの出来事を書く口が要る置き場。出来事を書く置き場と、書く前とあとの状態を比べるための種類の置き場と、推定を終えたときの出来事のために推定の予定と試みを読む置き場。
// 出来事を書く置き場は、記録の変化を書く入口と、登録簿の種類の置き場（書き込みの口）にしか渡さない
export const createEventWriteStores = (db: DrizzleSqliteDODatabase) => ({
  meal: createMealStore(db),
  mealEstimationStatus: createMealEstimationStatusStore(db),
  dish: createDishStore(db),
  dishEstimationStatus: createDishEstimationStatusStore(db),
  estimationEventWrite: createEstimationEventWriteStore(db),
  estimationSchedule: createEstimationScheduleStore(db),
  estimation: createEstimationStore(db),
  sentText: createSentTextStore(db),
  sentTextStatus: createSentTextStatusStore(db),
  replyEventWrite: createReplyEventWriteStore(db),
});
