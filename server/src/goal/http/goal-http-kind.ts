import { z } from "@hono/zod-openapi";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import { computeGoalDirection } from "../domain/compute-goal-direction";
import { type Goal, pacePlans } from "../domain/goal";
import { goalDirections } from "../domain/goal-direction";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
const goalRecordSchema = z
  .object({
    id: z.string(),
    startedOn: z.string().openapi({
      description: "開始の日（YYYY-MM-DD）。目標が当たり始める日",
      example: "2026-10-01",
    }),
    startingWeightTrendKg: z.number().openapi({
      description: "開始の日以前で最も新しい体重の傾向",
    }),
    targetWeightKg: z.number(),
    decidedAt: z.number().int().openapi({ description: "UNIX 時刻のミリ秒（UTC）" }),
    timeZone: z.string().openapi({
      description: "目標を決めた要求のタイムゾーン",
      example: "Asia/Tokyo",
    }),
    direction: z.enum(goalDirections).openapi({
      description:
        "向き（減量・増量・維持）。weightChange が無ければ維持、あれば目標体重が開始の日の体重の傾向より小さいとき減量、ほかは増量",
    }),
    weightChange: z
      .object({
        deadlineOn: z
          .string()
          .openapi({ description: "期限（YYYY-MM-DD）", example: "2026-12-24" }),
        pacePlan: z.enum(pacePlans).openapi({
          description: "速さの案。ゆるめ・標準・ハードと、自分で決めた目標体重（custom）",
        }),
      })
      .optional()
      .openapi({ description: "減量・増量の目標だけに付く" }),
    closure: z
      .object({
        endedOn: z.string().openapi({
          description: "終わった日（YYYY-MM-DD）。次の目標の開始の日",
          example: "2026-10-20",
        }),
        nextGoalId: z.string(),
      })
      .optional()
      .openapi({ description: "閉じた目標だけに付く。閉じると、同じ目標の変更がもう一度届く" }),
  })
  .openapi({
    description: "kind が goal の変更の record。目標は消えない",
  });

export const goalHttpKind: HttpRecordKind<Goal, never, typeof goalRecordSchema> = {
  // サーバーだけが書く種類なので、端末からの書き込みは届かない
  writes: undefined,
  recordSchema: goalRecordSchema,
  toRecord: (value) => ({
    id: value.id,
    startedOn: value.startedOn,
    startingWeightTrendKg: value.startingWeightTrendKg,
    targetWeightKg: value.targetWeightKg,
    decidedAt: value.decidedAt.getTime(),
    timeZone: value.timeZone,
    direction: computeGoalDirection(value),
    weightChange: value.weightChange,
    closure: value.closure,
  }),
};
