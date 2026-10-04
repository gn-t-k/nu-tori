import type { z } from "@hono/zod-openapi";
import type { RecordType } from "../../domain/record-type";
import type { RejectedRecord } from "../../domain/sync-ledger/pushed-result";
import type { syncWriteCurrentSchema } from "./sync-write-current-schema";
import { toChangeBody } from "./to-change-body";

export const toSyncWriteCurrent = ({
  recordType,
  recordId,
  current,
}: RejectedRecord<RecordType, unknown>): z.infer<typeof syncWriteCurrentSchema> => {
  if (current.status === "absent") {
    return { status: "absent" };
  }
  // 取りに行く変更と同じ変換を通す
  return { status: current.status, change: toChangeBody(recordType, recordId, current) };
};
