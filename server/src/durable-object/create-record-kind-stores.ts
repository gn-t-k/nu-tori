import { drizzle } from "drizzle-orm/durable-sqlite";
import { createAccountSettingsStore } from "../account-settings/durable-object/create-account-settings-store";
import type { RecordKindStores } from "../domain/record-kind-stores";

// 登録簿の種類の置き場を作る。種類のまとまりの durable-object/ にある実装を、名前の順に1行ずつ足す
export const createRecordKindStores = (storage: DurableObjectStorage): RecordKindStores => {
  const db = drizzle(storage);
  return {
    accountSettings: createAccountSettingsStore(db),
  };
};
