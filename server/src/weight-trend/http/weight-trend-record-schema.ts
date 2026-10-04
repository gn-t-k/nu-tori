import { z } from "@hono/zod-openapi";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
export const weightTrendRecordSchema = z
  .object({
    days: z
      .array(
        z.object({
          calendarDay: z.string().openapi({ description: "YYYY-MM-DD", example: "2026-09-01" }),
          trendKg: z.number().openapi({ description: "丸めない。見せるときに丸める" }),
        }),
      )
      .openapi({
        description:
          "始まり（最初の体重記録の日）から最後の体重記録の日まで、1日ずつ日の順に並ぶ。取りに行くたびに並び全体が届くので、端末はキャッシュを置き換える",
      }),
  })
  .openapi({
    description:
      "kind が weight_trend の変更の record。recordId は weight_trend の1つだけ。体重記録が1つも無くなると、kind が weight_trend_absence で record が空の変更が届く",
  });
