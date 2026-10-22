import { z } from "@hono/zod-openapi";
import { dailyGuideMainReasons } from "../../daily-guide/domain/daily-guide";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import { type WeeklyReview, weeklyReviewDeferralReasons } from "../domain/weekly-review";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない。
// ずれの向きは端末が使わないので載せない
const weeklyReviewRecordSchema = z
  .object({
    id: z.string(),
    effectiveOn: z.string().openapi({
      description: "新しい1日の目安を当てる月曜（YYYY-MM-DD）。見直す入力の月〜日はその前の週",
      example: "2026-10-19",
    }),
    reviewedAt: z.number().int().openapi({ description: "UNIX 時刻のミリ秒（UTC）" }),
    timeZone: z.string().openapi({
      description: "見直しを起こした要求のタイムゾーン",
      example: "Asia/Tokyo",
    }),
    deferral: z
      .object({
        reason: z.enum(weeklyReviewDeferralReasons).openapi({
          description:
            "見送りの理由。サブスクリプション切れ（subscription_expired）、使い始めて1週に満たない（within_first_week）、体重が無い（no_weight）、食事の記録が少ない（few_meal_records）",
        }),
        goalId: z.string().openapi({
          description: "その週に当てた目標の ID。目標の変更より先に届くことがある",
        }),
      })
      .optional()
      .openapi({ description: "見送った週だけに付く。review とどちらか一方が付く" }),
    review: z
      .object({
        expenditureEstimateId: z.string().openapi({
          description: "見直した推定消費カロリーの推定の ID。推定の変更より先に届くことがある",
        }),
        dailyGuideId: z.string().openapi({
          description: "見直した1日の目安の ID。1日の目安の変更より先に届くことがある",
        }),
        mainReason: z.enum(dailyGuideMainReasons).openapi({
          description:
            "1日の目安が変わった主な理由。推定消費カロリーの変化（expenditure_change）、残りの差の変化（balance_change）",
        }),
      })
      .optional()
      .openapi({ description: "見直せた週だけに付く。deferral とどちらか一方が付く" }),
  })
  .openapi({
    description: "kind が weekly_review の変更の record。週の見直しは消えない",
  });

export const weeklyReviewHttpKind: HttpRecordKind<
  WeeklyReview,
  never,
  typeof weeklyReviewRecordSchema
> = {
  // サーバーだけが書く種類なので、端末からの書き込みは届かない
  writes: undefined,
  recordSchema: weeklyReviewRecordSchema,
  toRecord: ({ outcome, ...value }) => ({
    id: value.id,
    effectiveOn: value.effectiveOn,
    reviewedAt: value.reviewedAt.getTime(),
    timeZone: value.timeZone,
    deferral:
      outcome.type === "deferred" ? { reason: outcome.reason, goalId: outcome.goalId } : undefined,
    review:
      outcome.type === "reviewed"
        ? {
            expenditureEstimateId: outcome.expenditureEstimateId,
            dailyGuideId: outcome.dailyGuideId,
            mainReason: outcome.mainReason,
          }
        : undefined,
  }),
};
