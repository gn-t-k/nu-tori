import { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { CustomTargetWeightAssessment } from "../../goal/domain/assess-custom-target-weight";
import { dailyGuidePlanSchema, toDailyGuidePlan } from "./daily-guide-plan-schema";
import { proposalPaceSchema } from "./proposal-pace-schema";

const startedOnSchema = z.string().openapi({ description: "計算に使った開始の日（YYYY-MM-DD）" });

// 自分で決める目標体重の応答。理由の値は、増えても古い版のアプリが読めるよう文字列で持つ
export const customTargetWeightAssessmentSchema = z
  .discriminatedUnion("status", [
    z
      .object({
        startedOn: startedOnSchema,
        status: z.literal("accepted"),
        dailyGuide: dailyGuidePlanSchema,
        difficulty: proposalPaceSchema,
        dailyGuideDifferenceKcal: z.number().int().openapi({
          description: "1日の目安と推定消費カロリーの差（50 kcal 単位。少ないときは負）",
        }),
      })
      .openapi("AcceptedCustomTargetWeight", {
        description: "受け付ける。difficulty（大変さ）は、必要な速さを案の速さで区切った段階",
      }),
    z
      .object({
        startedOn: startedOnSchema,
        status: z.literal("rejected"),
        rejectionReason: z.string().openapi({
          description:
            "pace_too_fast（速すぎる）・daily_guide_below_minimum（下限 1,200 kcal）・not_on_direction_side（体重の傾向より向きの側に出ない）",
          example: "pace_too_fast",
        }),
        nearestAcceptedTargetWeightKg: z.number().optional().openapi({
          description:
            "その期限に受け付ける目標体重があるときだけ付く。受け付けるいちばん近い目標体重",
        }),
      })
      .openapi("RejectedCustomTargetWeight", { description: "受け付けない" }),
  ])
  .openapi("CustomTargetWeightAssessment");

export const toCustomTargetWeightAssessmentResponse = ({
  startedOn,
  evaluation,
}: CustomTargetWeightAssessment): z.infer<typeof customTargetWeightAssessmentSchema> =>
  match(evaluation)
    .returnType<z.infer<typeof customTargetWeightAssessmentSchema>>()
    .with(
      { status: "accepted" },
      ({ status, dailyGuide, difficulty, dailyGuideDifferenceKcal }) => ({
        startedOn,
        status,
        dailyGuide: toDailyGuidePlan(dailyGuide),
        difficulty,
        dailyGuideDifferenceKcal,
      }),
    )
    .with({ status: "rejected" }, ({ status, reason, nearestAcceptedTargetWeightKg }) => ({
      startedOn,
      status,
      rejectionReason: reason,
      ...(nearestAcceptedTargetWeightKg === undefined ? {} : { nearestAcceptedTargetWeightKg }),
    }))
    .exhaustive();
