import type { SyncChange } from "../../domain/sync-change";
import { httpRecordKinds } from "./http-record-kinds";

export const toSyncChangeResponse = ({ sequence, recordType, recordId, current }: SyncChange) => {
  const kind = httpRecordKinds.find(({ name }) => name === recordType);
  if (kind === undefined) {
    throw new Error(`受け口の登録簿に無い種類の変更: ${recordType}`);
  }
  return kind.toChangeResponse(sequence, current, recordId);
};
