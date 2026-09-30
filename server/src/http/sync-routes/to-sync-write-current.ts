import type { z } from "@hono/zod-openapi";
import type { RecordType } from "../../domain/record-type";
import type { RejectedRecord } from "../../domain/sync-ledger/pushed-result";
import { httpRecordKinds } from "./http-record-kinds";
import type { syncWriteCurrentSchema } from "./sync-write-current-schema";

export const toSyncWriteCurrent = ({
  recordType,
  recordId,
  current,
}: RejectedRecord<RecordType, unknown>): z.infer<typeof syncWriteCurrentSchema> => {
  if (current.status === "absent") {
    return { status: "absent" };
  }
  const kind = httpRecordKinds.find(({ name }) => name === recordType);
  if (kind === undefined) {
    throw new Error(`受け口の登録簿に無い種類の今の値: ${recordType}`);
  }
  // 取りに行く変更と同じ変換を通し、通し番号だけを外す
  const change = kind.toChangeResponse(0, current, recordId);
  return {
    status: current.status,
    change: { kind: change.kind, recordId: change.recordId, record: change.record },
  };
};
