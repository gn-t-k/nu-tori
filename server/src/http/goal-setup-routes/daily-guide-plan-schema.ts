import { z } from "@hono/zod-openapi";

// まだ決めていない目標の、1日の目安と P・F・C の目安
export const dailyGuidePlanSchema = z
  .object({
    energyKcal: z.number().int(),
    proteinG: z.number().int(),
    fatG: z.number().int(),
    carbohydrateG: z.number().int(),
  })
  .openapi("DailyGuidePlan");

// 当たった上限と下限は、目標を決めたときに記録に残すもので、案には載せない
export const toDailyGuidePlan = ({
  energyKcal,
  proteinG,
  fatG,
  carbohydrateG,
}: z.infer<typeof dailyGuidePlanSchema>): z.infer<typeof dailyGuidePlanSchema> => ({
  energyKcal,
  proteinG,
  fatG,
  carbohydrateG,
});
