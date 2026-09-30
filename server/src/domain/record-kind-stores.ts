import type { WeightRecordStore } from "../weight-record/domain/weight-record-store";

// 登録簿の種類が使う置き場。種類を足すときは、種類の名前で1つずつ足す
export type RecordKindStores = {
  weightRecord: WeightRecordStore;
};
