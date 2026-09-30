import { z } from "@hono/zod-openapi";

// Date が表せる範囲。これを超える時刻は、日付の計算で例外になる
const maximumTimestamp = 8.64e15;

export const weightRecordFields = {
  id: z.string().min(1),
  weightKg: z.number(),
  measuredAt: z
    .number()
    .int()
    .min(-maximumTimestamp)
    .max(maximumTimestamp)
    .openapi({ description: "UNIX 時刻のミリ秒（UTC）" }),
  timeZone: z.string().openapi({ example: "Asia/Tokyo" }),
};
