import type { z } from "@hono/zod-openapi";
import type { SyncWrite } from "../../domain/sync-write";
import { httpRecordKinds } from "./http-record-kinds";
import type { syncWriteSchema } from "./sync-write-schema";

export const toSyncWrite = (write: z.infer<typeof syncWriteSchema>): SyncWrite => {
  const registered = Object.values(httpRecordKinds).find((kind) =>
    kind.writeTypes.includes(write.type),
  );
  if (registered === undefined) {
    throw new Error(`受け口の登録簿に無い書き込み: ${write.type}`);
  }
  return registered.toWrite(write);
};
