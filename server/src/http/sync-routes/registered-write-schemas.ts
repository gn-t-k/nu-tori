import type { z } from "@hono/zod-openapi";
import { accountSettingsWriteSchemas } from "../../account-settings/http/account-settings-write-schemas";
import type { RecordType } from "../../domain/record-type";
import { mealWriteSchemas } from "../../meal/http/meal-write-schemas";
import { weightRecordWriteSchemas } from "../../weight-record/http/weight-record-write-schemas";

// 種類ごとの書き込みのスキーマ。RecordType をキーにするので、種類を足して行を足し忘れるとコンパイルが落ちる。
// 種類ごとの型を保つため、各行は as const の並び
const writeSchemasByRecordType = {
  account_settings: accountSettingsWriteSchemas,
  meal: mealWriteSchemas,
  meal_estimation_status: [],
  weight_record: weightRecordWriteSchemas,
} as const satisfies { [K in RecordType]: readonly z.ZodType[] };

// z.discriminatedUnion に渡す並び（表から導く）。先頭の1つを分けるのは、型を空でない並びにするため
const [first, ...rest] = Object.values(writeSchemasByRecordType).flat();
if (first === undefined) {
  throw new Error("書き込みのスキーマが1つも登録されていない");
}
export const registeredWriteSchemas = [first, ...rest] as const;
