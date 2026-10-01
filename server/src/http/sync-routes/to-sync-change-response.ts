import type { SyncChange } from "../../domain/sync-change";
import { httpRecordKinds } from "./http-record-kinds";

export const toSyncChangeResponse = ({ sequence, recordType, recordId, current }: SyncChange) => {
  const kind = httpRecordKinds[recordType];
  return kind.toChangeResponse(sequence, current, recordId);
};
