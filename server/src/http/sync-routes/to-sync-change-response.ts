import type { SyncChange } from "../../domain/sync-change";
import { httpRecordKinds } from "./http-record-kinds";

export const toSyncChangeResponse = ({ sequence, recordType, recordId, current }: SyncChange) => {
  // 記録が無くなったことを届ける種類（体重の傾向）だけが absent を返す。値を持たないので、種類によらず同じ形にする
  if (current.status === "absent") {
    return { sequence, kind: `${recordType}_absence`, recordId, record: {} };
  }
  const kind = httpRecordKinds[recordType];
  return kind.toChangeResponse(sequence, current, recordId);
};
