import { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import { initialExpenditureSources } from "../../expenditure-estimate/domain/expenditure-estimate";
import type { GoalProposals } from "../../goal/domain/propose-goals-on-basis";
import { dailyGuidePlanSchema, toDailyGuidePlan } from "./daily-guide-plan-schema";
import { proposalPaceSchema } from "./proposal-pace-schema";

// 理由の値は、増えても古い版のアプリが読めるよう文字列で持つ（アプリは知らない理由を「知らない理由」として見せる）
const goalProposalSchema = z
  .discriminatedUnion("status", [
    z
      .object({
        pace: proposalPaceSchema,
        status: z.literal("offered"),
        targetWeightKg: z.number(),
        dailyGuide: dailyGuidePlanSchema,
        difficulty: proposalPaceSchema,
        dailyGuideDifferenceKcal: z.number().int().openapi({
          description: "1日の目安と推定消費カロリーの差（50 kcal 単位。少ないときは負）",
        }),
      })
      .openapi("OfferedGoalProposal", {
        description: "出せる案。difficulty（大変さ）は、その案の段階（pace と同じ値）",
      }),
    z
      .object({
        pace: proposalPaceSchema,
        status: z.literal("unavailable"),
        unavailableReason: z.string().openapi({
          description: "daily_guide_below_minimum（1日の目安が下限 1,200 kcal を下回る）",
          example: "daily_guide_below_minimum",
        }),
      })
      .openapi("UnavailableGoalProposal", { description: "出せない枠" }),
  ])
  .openapi("GoalProposal", { description: "ゆるめ・標準・ハードの枠の1つ" });

const acceptedTargetWeightRangeSchema = z
  .object({
    minimumKg: z.number(),
    maximumKg: z.number(),
    fastestEndReason: z.string().openapi({
      description:
        "いちばん速い端（減量は下の端、増量は上の端）を決めた理由。pace_too_fast（ハード案の速さ）・daily_guide_below_minimum（下限 1,200 kcal）",
      example: "pace_too_fast",
    }),
  })
  .openapi("AcceptedTargetWeightRange", {
    description: "自分で決める目標体重の受け付ける幅（0.1 kg 単位、両端を含む）",
  });

// 向きによらず載せる、計算の元
const goalProposalsBasisShape = {
  startedOn: z.string().openapi({
    description:
      "開始の日（YYYY-MM-DD）。端末の今のタイムゾーンでの今日。立て直すときに今日が今の目標の開始の日より前なら、今の目標の開始の日。期限の日数はこの日から数える",
  }),
  expenditureKcal: z.number().int().openapi({ description: "計算に使った推定消費カロリー" }),
  expenditureSource: z
    .enum([...initialExpenditureSources, "current"])
    .openapi("GoalSetupExpenditureSource", {
      description:
        "推定消費カロリーの出どころ。back_calculated（逆算）・formula（式）・current（今の推定。立て直すとき）",
    }),
  startingWeightTrendKg: z.number().openapi({
    description: "計算に使った、開始の日の体重の傾向。丸めていない",
  }),
  lastWeightRecordedOn: z.string().openapi({
    description: "体重の傾向の元になった、開始の日以前で最後の体重記録の日（YYYY-MM-DD）",
  }),
};

// 減量・増量のときに載せる、期限までの案
const weightChangeProposalsShape = {
  ...goalProposalsBasisShape,
  deadlineOn: z.string().openapi({ description: "期限（YYYY-MM-DD）" }),
  proposals: z.array(goalProposalSchema).openapi({
    description: "ゆるめ・標準・ハードの3つの枠を、いつもこの順に",
  }),
  acceptedTargetWeightRange: acceptedTargetWeightRangeSchema.optional(),
};

// 目標案の応答。目標を決める要求が決めずに返す「新しい案」も、この形にする。
// 受け付ける幅は、受け付ける目標体重が1つも無いときに付かない
export const goalProposalsSchema = z
  .discriminatedUnion("direction", [
    z
      .object({
        ...goalProposalsBasisShape,
        direction: z.literal("maintain"),
        maintenance: z
          .object({ targetWeightKg: z.number(), dailyGuide: dailyGuidePlanSchema })
          .openapi("GoalMaintenancePlan"),
      })
      .openapi("MaintainGoalProposals"),
    z
      .object({ ...weightChangeProposalsShape, direction: z.literal("lose") })
      .openapi("LoseGoalProposals"),
    z
      .object({ ...weightChangeProposalsShape, direction: z.literal("gain") })
      .openapi("GainGoalProposals"),
  ])
  .openapi("GoalProposals", {
    description:
      "減量・増量は期限までの3つの枠と自分で決める目標体重の受け付ける幅、維持は目標体重と1日の目安",
  });

export const toGoalProposalsResponse = ({
  startedOn,
  startingWeightTrend,
  expenditure,
  plan,
}: GoalProposals): z.infer<typeof goalProposalsSchema> => {
  // 送る JSON のキーの並びを前と同じ（開始の日、向き、計算の元）に保つため、開始の日を分けて置く
  const measured = {
    expenditureKcal: expenditure.kcal,
    expenditureSource: expenditure.source,
    startingWeightTrendKg: startingWeightTrend.trendKg,
    lastWeightRecordedOn: startingWeightTrend.lastWeightRecordedOn,
  };
  return match(plan)
    .returnType<z.infer<typeof goalProposalsSchema>>()
    .with({ direction: "maintain" }, ({ direction, maintenance }) => ({
      startedOn,
      direction,
      ...measured,
      maintenance: {
        targetWeightKg: maintenance.targetWeightKg,
        dailyGuide: toDailyGuidePlan(maintenance.dailyGuide),
      },
    }))
    .with(
      { direction: "lose" },
      { direction: "gain" },
      ({ direction, deadlineOn, proposals, acceptedTargetWeightRange }) => ({
        startedOn,
        direction,
        ...measured,
        deadlineOn,
        proposals: proposals.map((proposal) =>
          match(proposal)
            .returnType<z.infer<typeof goalProposalSchema>>()
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
    .exhaustive();
};
