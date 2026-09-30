import type { RecordKindStores } from "../domain/record-kind-stores";
import { createWeightRecordStore } from "../weight-record/durable-object/create-weight-record-store";

// 登録簿の種類の置き場を作る。種類のまとまりの durable-object/ にある実装を、名前の順に1行ずつ足す
export const createRecordKindStores = (storage: DurableObjectStorage): RecordKindStores => ({
  weightRecord: createWeightRecordStore(storage),
});
