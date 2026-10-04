import { z } from "@hono/zod-openapi";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
export const ingredientRecordSchema = z
  .object({
    id: z.string(),
    dishId: z.string(),
    name: z.string(),
    quantity: z.number(),
    unit: z.string(),
    edibleGramsPerUnit: z.number(),
    positionInDish: z.number().int(),
    nutrientSource: z.discriminatedUnion("type", [
      z.object({ type: z.literal("nutrition_label"), labelBasisGrams: z.number() }),
      z.object({ type: z.literal("food_composition"), foodNumber: z.string() }),
      z.object({ type: z.literal("estimated") }),
    ]),
    nutrients: z.record(z.string(), z.number()).openapi({
      description: "項目の名前は shared/nutrients.json。不明の項目はキーを持たない",
    }),
  })
  .openapi({
    description:
      "kind が ingredient の変更の record。消えたら kind が ingredient_deletion で record が空の変更が届く",
  });
