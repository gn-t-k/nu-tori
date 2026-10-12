import { drizzle } from "drizzle-orm/durable-sqlite";
import { createDishStore } from "../dish/durable-object/create-dish-store";
import { createDishEstimationStatusStore } from "../dish-estimation-status/durable-object/create-dish-estimation-status-store";
import type { RecordChangeWriter } from "../domain/record-change-writer";
import { writeRecordChanges } from "../domain/write-record-changes";
import { createEstimationEventWriteStore } from "../estimation/durable-object/create-estimation-event-write-store";
import { createMealStore } from "../meal/durable-object/create-meal-store";
import { createMealEstimationStatusStore } from "../meal-estimation-status/durable-object/create-meal-estimation-status-store";
import { createReplyEventWriteStore } from "../reply/durable-object/create-reply-event-write-store";
import { createSentTextStore } from "../sent-text/durable-object/create-sent-text-store";
import { createSentTextStatusStore } from "../sent-text-status/durable-object/create-sent-text-status-store";
import { createLedgerStore } from "./create-ledger-store";

// 記録の変化を書く入口を、Durable Object の置き場で組む。
// 推定と返事の流れの出来事を書く置き場は、ここと登録簿の種類の置き場（書き込みの口）にしか渡さない
export const createRecordChangeWriter = (storage: DurableObjectStorage): RecordChangeWriter => {
  const db = drizzle(storage);
  const ledgerStore = createLedgerStore(storage);
  const stores = {
    meal: createMealStore(db),
    mealEstimationStatus: createMealEstimationStatusStore(db),
    dish: createDishStore(db),
    dishEstimationStatus: createDishEstimationStatusStore(db),
    estimationEventWrite: createEstimationEventWriteStore(db),
    sentText: createSentTextStore(db),
    sentTextStatus: createSentTextStatusStore(db),
    replyEventWrite: createReplyEventWriteStore(db),
  };
  return (run) => writeRecordChanges(ledgerStore, stores, run);
};
