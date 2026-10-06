import type { Dish } from "../domain/dish";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import { dishRecordSchema } from "./dish-record-schema";
import { dishWriteSchemas } from "./dish-write-schemas";
import { toDishRecord } from "./to-dish-record";
import { toDishWrite } from "./to-dish-write";

export const dishHttpKind: HttpRecordKind<
  Dish,
  (typeof dishWriteSchemas)[number],
  typeof dishRecordSchema
> = {
  writes: { schemas: dishWriteSchemas, toWrite: toDishWrite },
  recordSchema: dishRecordSchema,
  toRecord: toDishRecord,
};
