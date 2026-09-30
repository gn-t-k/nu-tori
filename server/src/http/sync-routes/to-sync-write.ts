import type { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { SyncWrite } from "../../domain/sync-write";
import {
  toCreateWeightRecordWrite,
  toSourceDeletedWeightRecordWrite,
  toUpdateWeightRecordWrite,
} from "../../weight-record/http/to-weight-record-write";
import { httpRecordKinds } from "./http-record-kinds";
import type { LegacyWrite, syncWriteSchema } from "./sync-write-schema";

const isLegacyWrite = (write: z.infer<typeof syncWriteSchema>): write is LegacyWrite =>
  httpRecordKinds.every((kind) => !kind.writeTypes.includes(write.type));

const toLegacySyncWrite = (write: LegacyWrite): SyncWrite =>
  match(write)
    .with({ type: "create_weight_record" }, toCreateWeightRecordWrite)
    .with({ type: "update_weight_record" }, toUpdateWeightRecordWrite)
    .with({ type: "source_deleted_weight_record" }, toSourceDeletedWeightRecordWrite)
    .exhaustive();

export const toSyncWrite = (write: z.infer<typeof syncWriteSchema>): SyncWrite => {
  if (isLegacyWrite(write)) {
    return toLegacySyncWrite(write);
  }
  const registered = httpRecordKinds.find((kind) => kind.writeTypes.includes(write.type));
  if (registered === undefined) {
    throw new Error(`受け口の登録簿に無い書き込み: ${write.type}`);
  }
  return registered.toWrite(write);
};
