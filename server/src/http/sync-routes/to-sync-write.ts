import type { z } from "@hono/zod-openapi";
import type { SyncWrite } from "../../domain/sync-write";
import type { HttpRecordKind } from "./http-record-kind";
import { httpRecordKinds } from "./http-record-kinds";
import type { syncWriteSchema } from "./sync-write-schema";

// 種類ごとの書き込みの型は、スキーマで受け付けた時点で決まっているので、種類を1つの型で扱う
const kinds: readonly HttpRecordKind[] = Object.values(httpRecordKinds);

export const toSyncWrite = (write: z.infer<typeof syncWriteSchema>): SyncWrite => {
  const writes = kinds
    .map((kind) => kind.writes)
    .find((candidate) =>
      candidate?.schemas.some((schema) => schema.shape.type.value === write.type),
    );
  if (writes === undefined) {
    throw new Error(`受け口の登録簿に無い書き込み: ${write.type}`);
  }
  return writes.toWrite(write);
};
