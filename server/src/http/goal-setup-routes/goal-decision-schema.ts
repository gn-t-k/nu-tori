import { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { GoalDecision } from "../../goal/domain/decide-goal";
import { toChangeBody } from "../sync-routes/to-change-body";
import { goalProposalsSchema, toGoalProposalsResponse } from "./goal-proposals-schema";

// 目標を決める要求の応答。区分の値は、増えても古い版のアプリが読めるよう文字列で持つ
export const goalDecisionSchema = z
  .object({
    status: z.string().openapi({
      description:
        "decided（決めた。同じ要求の ID の再送を含む）・recalculated（開始の日か見せていた値が違ったので、決めずに計算し直した）・custom_target_weight_rejected（自分で決めた目標体重を受け付けないので、決めていない）",
      example: "decided",
    }),
    changes: z
      .array(
        z
          .object({
            kind: z.string().openapi({
              description: "goal・daily_guide・expenditure_estimate",
              example: "goal",
            }),
            recordId: z.string(),
            record: z.record(z.string(), z.unknown()),
          })
          .openapi("GoalDecisionChange", {
            description:
              "決めた記録。取りに行く変更（SyncChange）から通し番号を除いた形で、record は種類ごとの GoalRecord・DailyGuideRecord・ExpenditureEstimateRecord",
          }),
      )
      .optional()
      .openapi({
        description:
          "decided のときだけ。端末はキャッシュに書く（同じ記録は同期でも届く）。並びは、立て直しなら閉じた前の目標、新しい目標、1日の目安、初めての目標なら推定消費カロリー",
      }),
    proposals: goalProposalsSchema.optional().openapi({
      description: "recalculated のときだけ。そのときの体重の傾向と開始の日で出し直した目標案",
    }),
    startedOn: z.string().optional().openapi({
      description: "custom_target_weight_rejected のときだけ。計算に使った開始の日（YYYY-MM-DD）",
    }),
    rejectionReason: z.string().optional().openapi({
      description:
        "custom_target_weight_rejected のときだけ。pace_too_fast（速すぎる）・daily_guide_below_minimum（下限 1,200 kcal）・not_on_direction_side（体重の傾向より向きの側に出ない）",
    }),
    nearestAcceptedTargetWeightKg: z.number().optional().openapi({
      description:
        "custom_target_weight_rejected で、その期限に受け付ける目標体重があるときだけ。受け付けるいちばん近い目標体重",
    }),
  })
  .openapi("GoalDecision");

export const toGoalDecisionResponse = (
  decision: GoalDecision,
): z.infer<typeof goalDecisionSchema> =>
  match(decision)
    .with({ status: "decided" }, ({ status, records }) => ({
      status,
      changes: records.map(({ recordType, value }) =>
        toChangeBody(recordType, value.id, { status: "value", value }),
      ),
    }))
    .with({ status: "recalculated" }, ({ status, proposals }) => ({
      status,
      proposals: toGoalProposalsResponse(proposals),
    }))
    .with(
      { status: "custom_target_weight_rejected" },
      ({ status, startedOn, reason, nearestAcceptedTargetWeightKg }) => ({
        status,
        startedOn,
        rejectionReason: reason,
        ...(nearestAcceptedTargetWeightKg === undefined ? {} : { nearestAcceptedTargetWeightKg }),
      }),
    )
    .exhaustive();
