import { z } from "@hono/zod-openapi";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
export const usualWeighingTimeRecordSchema = z
  .object({
    minuteOfDay: z.number().int().min(0).max(1435).openapi({
      description: "その日の何分目（5 分単位）。例: 7:15 は 435",
      example: 435,
    }),
  })
  .openapi({
    description:
      "kind が usual_weighing_time の変更の record。アカウントに1つで、サーバーが初めて学んだときに recordId を振る。学ぶまでは変更が届かない（端末は朝7時を使う）。一度届いたら消えない",
  });
