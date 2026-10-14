import { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { GoalProposals } from "../../goal/domain/propose-goals";
import { dailyGuidePlanSchema, toDailyGuidePlan } from "./daily-guide-plan-schema";

// 目標案の応答。目標を決める要求が決めずに返す「新しい案」も、この形にする。
// 区分の値は、増えても古い版のアプリが読めるよう文字列で持つ
export const goalProposalsSchema = z
  .object({
    startedOn: z.string().openapi({
      description:
        "開始の日（YYYY-MM-DD）。端末の今のタイムゾーンでの今日。立て直すときに今日が今の目標の開始の日より前なら、今の目標の開始の日。期限の日数はこの日から数える",
    }),
    direction: z.string().openapi({ description: "lose・gain・maintain", example: "lose" }),
    expenditureKcal: z.number().int().openapi({ description: "計算に使った推定消費カロリー" }),
    expenditureSource: z.string().openapi({
      description:
        "推定消費カロリーの出どころ。back_calculated（逆算）・formula（式）・current（今の推定。立て直すとき）",
      example: "back_calculated",
    }),
    startingWeightTrendKg: z.number().openapi({
      description: "計算に使った、開始の日の体重の傾向。丸めていない",
    }),
    lastWeightRecordedOn: z.string().openapi({
      description: "体重の傾向の元になった、開始の日以前で最後の体重記録の日（YYYY-MM-DD）",
    }),
    deadlineOn: z.string().optional().openapi({ description: "減量・増量のときだけ付く" }),
    proposals: z
      .array(
        z
          .object({
            pace: z.string().openapi({ description: "gentle・standard・hard", example: "gentle" }),
            status: z.string().openapi({
              description: "offered（出せる）・unavailable（出せない）",
              example: "offered",
            }),
            targetWeightKg: z.number().optional().openapi({ description: "offered のときだけ" }),
            dailyGuide: dailyGuidePlanSchema.optional().openapi({
              description: "offered のときだけ",
            }),
            difficulty: z.string().optional().openapi({
              description: "offered のときだけ。大変さ。案ではその案の段階（pace と同じ値）",
            }),
            dailyGuideDifferenceKcal: z.number().int().optional().openapi({
              description:
                "offered のときだけ。1日の目安と推定消費カロリーの差（50 kcal 単位。少ないときは負）",
            }),
            unavailableReason: z.string().optional().openapi({
              description:
                "unavailable のときだけ。daily_guide_below_minimum（1日の目安が下限 1,200 kcal を下回る）",
            }),
          })
          .openapi("GoalProposal"),
      )
      .optional()
      .openapi({
        description: "減量・増量のときだけ付く。ゆるめ・標準・ハードの3つの枠を、いつもこの順に",
      }),
    acceptedTargetWeightRange: z
      .object({
        minimumKg: z.number(),
        maximumKg: z.number(),
        fastestEndReason: z.string().openapi({
          description:
            "いちばん速い端（減量は下の端、増量は上の端）を決めた理由。pace_too_fast（ハード案の速さ）・daily_guide_below_minimum（下限 1,200 kcal）",
        }),
      })
      .optional()
      .openapi({
        description:
          "自分で決める目標体重の受け付ける幅（0.1 kg 単位、両端を含む）。減量・増量で、受け付ける目標体重があるときだけ付く",
      }),
    maintenance: z
      .object({ targetWeightKg: z.number(), dailyGuide: dailyGuidePlanSchema })
      .optional()
      .openapi({ description: "維持のときだけ付く" }),
  })
  .openapi("GoalProposals");

export const toGoalProposalsResponse = ({
  startedOn,
  startingWeightTrend,
  expenditure,
  plan,
}: GoalProposals): z.infer<typeof goalProposalsSchema> => ({
  startedOn,
  direction: plan.direction,
  expenditureKcal: expenditure.kcal,
  expenditureSource: expenditure.source,
  startingWeightTrendKg: startingWeightTrend.trendKg,
  lastWeightRecordedOn: startingWeightTrend.lastWeightRecordedOn,
  ...match(plan)
    .with({ direction: "maintain" }, ({ maintenance }) => ({
      maintenance: {
        targetWeightKg: maintenance.targetWeightKg,
        dailyGuide: toDailyGuidePlan(maintenance.dailyGuide),
      },
    }))
    .with(
      { direction: "lose" },
      { direction: "gain" },
      ({ deadlineOn, proposals, acceptedTargetWeightRange }) => ({
        deadlineOn,
        proposals: proposals.map((proposal) =>
          match(proposal)
            .with(
              { status: "offered" },
              ({ pace, status, targetWeightKg, dailyGuide, dailyGuideDifferenceKcal }) => ({
                pace,
                status,
                targetWeightKg,
                dailyGuide: toDailyGuidePlan(dailyGuide),
                difficulty: pace,
                dailyGuideDifferenceKcal,
              }),
            )
            .with({ status: "unavailable" }, ({ pace, status, reason }) => ({
              pace,
              status,
              unavailableReason: reason,
            }))
            .exhaustive(),
        ),
        ...(acceptedTargetWeightRange === undefined ? {} : { acceptedTargetWeightRange }),
      }),
    )
    .exhaustive(),
});
