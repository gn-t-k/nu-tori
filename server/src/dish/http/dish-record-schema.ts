import { z } from "@hono/zod-openapi";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
export const dishRecordSchema = z
  .object({
    id: z.string(),
    mealId: z.string(),
    name: z.string().openapi({ description: "今の名前" }),
    // 量の無い料理（推定し直しが一度も当たっていない料理）は、量と単位と量の出どころを省く。
    // 1つ前の版のアプリは読めないので、最低バージョンで締め出す（#332 の「移行の決まりの例外」）
    quantity: z.number().optional().openapi({ description: "今の量。量の無い料理は省く" }),
    unit: z.string().optional().openapi({ description: "量の単位。量の無い料理は省く" }),
    quantitySource: z.enum(["estimated", "corrected"]).optional().openapi({
      description:
        "量の出どころ。推定したまま（estimated）か、料理の量を直した（corrected）か。量の無い料理は省く",
    }),
    positionInMeal: z.number().int(),
    version: z.number().int(),
  })
  .openapi({
    description:
      "kind が dish の変更の record。消えたら kind が dish_deletion で record が空の変更が届く",
  });
