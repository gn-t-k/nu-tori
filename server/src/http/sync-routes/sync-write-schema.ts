import { z } from "@hono/zod-openapi";
import { registeredWriteSchemas } from "./registered-write-schemas";

export const syncWriteSchema = z
  .discriminatedUnion("type", registeredWriteSchemas)
  .openapi("SyncWrite", {
    description: "アカウントの設定は、記録が無くても直す書き込みで送り、サーバーが無ければ作る",
  });
