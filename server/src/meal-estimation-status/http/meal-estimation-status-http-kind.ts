import { z } from "@hono/zod-openapi";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { MealEstimationStatus } from "../domain/meal-estimation-status";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
const mealEstimationStatusRecordSchema = z
  .object({
    mealId: z.string(),
    status: z.string().openapi({ example: "estimating" }),
  })
  .openapi({
    description:
      "kind が meal_estimation_status の変更の record。recordId は食事の ID。食事が消えたら kind が meal_estimation_status_deletion で record が空の変更が届く",
  });

export const mealEstimationStatusHttpKind: HttpRecordKind<
  MealEstimationStatus,
  never,
  typeof mealEstimationStatusRecordSchema
> = {
  // サーバーだけが書く種類なので、端末からの書き込みは届かない
  writes: undefined,
  recordSchema: mealEstimationStatusRecordSchema,
  toRecord: (value, mealId) => ({ mealId, status: value }),
};
