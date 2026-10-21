import { z } from "@hono/zod-openapi";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { DishEstimationStatus } from "../domain/dish-estimation-status";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
const dishEstimationStatusRecordSchema = z
  .object({
    dishId: z.string(),
    status: z.string().openapi({
      description:
        "推定中（estimating）、翌日に推定（deferred_to_next_day）、サブスクリプションを待っている（awaiting_subscription）、推定できた（estimated）、料理なし（no_dishes）、推定できなかった（failed）",
      example: "estimating",
    }),
  })
  .openapi({
    description:
      "kind が dish_estimation_status の変更の record。recordId は料理の ID。推定し直しをしていない料理の変更は届かない。料理が消えたら kind が dish_estimation_status_deletion で record が空の変更が届く",
  });

export const dishEstimationStatusHttpKind: HttpRecordKind<
  DishEstimationStatus,
  never,
  typeof dishEstimationStatusRecordSchema
> = {
  // サーバーだけが書く種類なので、端末からの書き込みは届かない
  writes: undefined,
  recordSchema: dishEstimationStatusRecordSchema,
  toRecord: (value, dishId) => ({ dishId, status: value }),
};
