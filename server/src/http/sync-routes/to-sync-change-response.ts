import type { SyncChange } from "../../domain/sync-change";
import { toChangeBody } from "./to-change-body";

export const toSyncChangeResponse = ({ sequence, recordType, recordId, current }: SyncChange) => ({
  sequence,
  ...toChangeBody(recordType, recordId, current),
});
