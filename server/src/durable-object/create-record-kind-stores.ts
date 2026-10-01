import { drizzle } from "drizzle-orm/durable-sqlite";
import { createAccountSettingsStore } from "../account-settings/durable-object/create-account-settings-store";
import type { RecordKindStores } from "../domain/record-kind-stores";
import { createMealStore } from "../meal/durable-object/create-meal-store";
import { createMealEstimationStatusStore } from "../meal-estimation-status/durable-object/create-meal-estimation-status-store";
import { createFirstSignInStore } from "./create-first-sign-in-store";
import { createWeightRecordStore } from "../weight-record/durable-object/create-weight-record-store";

// 登録簿の種類の置き場を作る。種類のまとまりの durable-object/ にある実装を、名前の順に1行ずつ足す
export const createRecordKindStores = (storage: DurableObjectStorage): RecordKindStores => {
  const db = drizzle(storage);
  return {
    accountSettings: createAccountSettingsStore(db),
    meal: createMealStore(db),
    mealEstimationStatus: createMealEstimationStatusStore(db),
    weightRecord: createWeightRecordStore(db),
    firstSignIn: createFirstSignInStore(db),
  };
};
