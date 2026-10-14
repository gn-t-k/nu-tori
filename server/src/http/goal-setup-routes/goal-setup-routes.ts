import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { R } from "@praha/byethrow";
import { captureException } from "@sentry/cloudflare";
import { match } from "ts-pattern";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { authenticateAccount } from "../authenticate-account";
import { dailyGuidePlanSchema, toDailyGuidePlan } from "./daily-guide-plan-schema";
import { deadlineOnSchema } from "./deadline-on-schema";
import { goalDecisionRequestSchema, toGoalDecisionRequest } from "./goal-decision-request-schema";
import { goalDecisionSchema, toGoalDecisionResponse } from "./goal-decision-schema";
import { GoalSetupRequestMalformedError } from "./goal-setup-request-malformed-error";
import { goalProposalsSchema, toGoalProposalsResponse } from "./goal-proposals-schema";
import { goalSetupSituationSchema, toGoalSetupSituation } from "./goal-setup-situation-schema";
import { rejectUnreadableJsonBody } from "./reject-unreadable-json-body";
import { respondGoalSetupRejected } from "./respond-goal-setup-rejected";
import { weightChangeDirectionSchema } from "./weight-change-direction-schema";

const rejectionSchema = z
  .object({
    code: z.string().openapi({
      description:
        "断った理由。malformed_request（形の誤り）・invalid_time_zone・body_data_out_of_range・deadline_out_of_range（開始の日から数えて 28〜182 日の外）・weight_record_missing（体重記録が1つも無い）・body_data_missing（逆算できず、身体データも無い）",
      example: "deadline_out_of_range",
    }),
  })
  .openapi("GoalSetupRejection");

// どれも不具合のときだけ届く（端末は、受け付ける値だけを選ばせる）
const rejectionResponses = {
  400: {
    description: "要求の形が違う",
    content: { "application/json": { schema: rejectionSchema } },
  },
  401: { description: "セッションが無いか、切れている" },
  422: {
    description: "形は合っているが、値を受け付けない",
    content: { "application/json": { schema: rejectionSchema } },
  },
  429: { description: "回数の歯止めにかかった" },
} as const;

// 選んだ向きと期限。維持は期限を持たない
const goalProposalsPlanSchema = z
  .discriminatedUnion("direction", [
    z.object({ direction: z.literal("maintain") }).openapi("GoalMaintainPlan"),
    z
      .object({ direction: z.literal("lose"), deadlineOn: deadlineOnSchema })
      .openapi("GoalLosePlan"),
    z
      .object({ direction: z.literal("gain"), deadlineOn: deadlineOnSchema })
      .openapi("GoalGainPlan"),
  ])
  .openapi("GoalProposalsPlan", { description: "選んだ向きと、減量・増量の期限" });

export const goalSetupRoutes = new OpenAPIHono<{ Bindings: Env }>({
  // 形の誤りも Sentry に送る。誤っていた場所と種類だけを持たせ、届いた値は載せない
  defaultHook: (result, c) => {
    if (result.success) {
      return undefined;
    }
    captureException(
      new GoalSetupRequestMalformedError({
        issues: result.error.issues.map(({ path, code }) => ({ path: path.join("."), code })),
      }),
    );
    return c.json({ code: "malformed_request" }, 400);
  },
})
  .openapi(
    createRoute({
      method: "post",
      path: "/v1/goal-setup/preview",
      operationId: "previewGoalSetup",
      summary: "目標の下見",
      description:
        "向きを選んだ直後に、逆算できるかと、減量の目標案を1つでも出せるかを答える。初めての目標では、先に体重記録を同期で送り切る。何も書かない",
      security: [{ session: [] }],
      middleware: [authenticateAccount, rejectUnreadableJsonBody] as const,
      request: {
        body: {
          required: true,
          content: {
            "application/json": {
              schema: goalSetupSituationSchema.extend({
                direction: z.enum(["lose", "gain", "maintain"]),
              }),
            },
          },
        },
      },
      responses: {
        200: {
          description: "下見の答え",
          content: {
            "application/json": {
              schema: z
                .object({
                  canBackCalculate: z.boolean().optional().openapi({
                    description:
                      "初めての目標のときだけ付く。推定消費カロリーを記録から逆算できるか。false なら、身体データを添えてもう一度下見を求める",
                  }),
                  canOfferLoseProposals: z.boolean().optional().openapi({
                    description:
                      "減量で、推定消費カロリーと体重の傾向を出せたときだけ付く。減量の目標案を1つでも出せるか。受け付けるいちばん短い期限（開始の日から 28 日）で確かめるので、true ならどの期限でも出せる",
                  }),
                })
                .openapi("GoalSetupPreview"),
            },
          },
        },
        ...rejectionResponses,
      },
    }),
    async (c) => {
      const { direction, ...situation } = c.req.valid("json");
      const previewed = await getAccountDurableObject(c.env, c.var.accountId).previewGoalSetup(
        c.var.accountId,
        { ...toGoalSetupSituation(situation), direction },
      );
      if (R.isFailure(previewed)) {
        return respondGoalSetupRejected(c, previewed.error);
      }
      const { canBackCalculate, canOfferLoseProposals } = previewed.value;
      return c.json(
        {
          ...(canBackCalculate === undefined ? {} : { canBackCalculate }),
          ...(canOfferLoseProposals === undefined ? {} : { canOfferLoseProposals }),
        },
        200,
      );
    },
  )
  .openapi(
    createRoute({
      method: "post",
      path: "/v1/goal-setup/proposals",
      operationId: "proposeGoals",
      summary: "目標案",
      description:
        "減量・増量は、期限までの3つの枠と、自分で決める目標体重の受け付ける幅を答える。維持は、目標体重と1日の目安を答える。そのときの体重の傾向で計算し、何も書かない",
      security: [{ session: [] }],
      middleware: [authenticateAccount, rejectUnreadableJsonBody] as const,
      request: {
        body: {
          required: true,
          content: {
            "application/json": {
              schema: goalSetupSituationSchema.extend({ plan: goalProposalsPlanSchema }),
            },
          },
        },
      },
      responses: {
        200: {
          description: "目標案",
          content: { "application/json": { schema: goalProposalsSchema } },
        },
        ...rejectionResponses,
      },
    }),
    async (c) => {
      const { plan, ...situation } = c.req.valid("json");
      const proposed = await getAccountDurableObject(c.env, c.var.accountId).proposeGoals(
        c.var.accountId,
        { ...toGoalSetupSituation(situation), plan },
      );
      if (R.isFailure(proposed)) {
        return respondGoalSetupRejected(c, proposed.error);
      }
      return c.json(toGoalProposalsResponse(proposed.value), 200);
    },
  )
  .openapi(
    createRoute({
      method: "post",
      path: "/v1/goal-setup/custom-target-weight",
      operationId: "assessCustomTargetWeight",
      summary: "自分で決める目標体重",
      description:
        "受け付けるなら、その目標体重の1日の目安と大変さを答える。受け付けないなら、受け付けるいちばん近い目標体重と理由を答える。何も書かない",
      security: [{ session: [] }],
      middleware: [authenticateAccount, rejectUnreadableJsonBody] as const,
      request: {
        body: {
          required: true,
          content: {
            "application/json": {
              schema: goalSetupSituationSchema.extend({
                direction: weightChangeDirectionSchema,
                deadlineOn: deadlineOnSchema,
                targetWeightKg: z.number().positive().openapi({
                  description: "0.1 kg 単位に丸めて確かめる",
                }),
              }),
            },
          },
        },
      },
      responses: {
        200: {
          description: "受け付けるかと、受け付けるときの1日の目安",
          content: {
            "application/json": {
              schema: z
                .object({
                  startedOn: z.string().openapi({
                    description: "計算に使った開始の日（YYYY-MM-DD）",
                  }),
                  status: z.string().openapi({
                    description: "accepted（受け付ける）・rejected（受け付けない）",
                    example: "accepted",
                  }),
                  dailyGuide: dailyGuidePlanSchema.optional().openapi({
                    description: "accepted のときだけ",
                  }),
                  difficulty: z.string().optional().openapi({
                    description:
                      "accepted のときだけ。大変さ。必要な速さを案の速さで区切った gentle・standard・hard",
                  }),
                  dailyGuideDifferenceKcal: z.number().int().optional().openapi({
                    description:
                      "accepted のときだけ。1日の目安と推定消費カロリーの差（50 kcal 単位。少ないときは負）",
                  }),
                  rejectionReason: z.string().optional().openapi({
                    description:
                      "rejected のときだけ。pace_too_fast（速すぎる）・daily_guide_below_minimum（下限 1,200 kcal）・not_on_direction_side（体重の傾向より向きの側に出ない）",
                  }),
                  nearestAcceptedTargetWeightKg: z.number().optional().openapi({
                    description:
                      "rejected で、その期限に受け付ける目標体重があるときだけ。受け付けるいちばん近い目標体重",
                  }),
                })
                .openapi("CustomTargetWeightAssessment"),
            },
          },
        },
        ...rejectionResponses,
      },
    }),
    async (c) => {
      const { direction, deadlineOn, targetWeightKg, ...situation } = c.req.valid("json");
      const assessed = await getAccountDurableObject(
        c.env,
        c.var.accountId,
      ).assessCustomTargetWeight(c.var.accountId, {
        ...toGoalSetupSituation(situation),
        direction,
        deadlineOn,
        targetWeightKg,
      });
      if (R.isFailure(assessed)) {
        return respondGoalSetupRejected(c, assessed.error);
      }
      const { startedOn, evaluation } = assessed.value;
      return c.json(
        {
          startedOn,
          ...match(evaluation)
            .with(
              { status: "accepted" },
              ({ status, dailyGuide, difficulty, dailyGuideDifferenceKcal }) => ({
                status,
                dailyGuide: toDailyGuidePlan(dailyGuide),
                difficulty,
                dailyGuideDifferenceKcal,
              }),
            )
            .with({ status: "rejected" }, ({ status, reason, nearestAcceptedTargetWeightKg }) => ({
              status,
              rejectionReason: reason,
              ...(nearestAcceptedTargetWeightKg === undefined
                ? {}
                : { nearestAcceptedTargetWeightKg }),
            }))
            .exhaustive(),
        },
        200,
      );
    },
  )
  .openapi(
    createRoute({
      method: "post",
      path: "/v1/goal-setup/decisions",
      operationId: "decideGoal",
      summary: "目標を決める",
      description:
        "そのときの体重の傾向と開始の日で計算し直し、端末が見せていた値と同じなら決めて、目標・1日の目安・（初めての目標なら）推定消費カロリーの記録を返す。同じ記録は同期でも届く。開始の日か見せていた値が違えば、決めずに新しい目標案を返す（開始の日がずれて期限が受け付ける幅の外に出たら、受け付けるいちばん近い日を期限にする）。自分で決めた目標体重を受け付けないときは、決めずにいちばん近い目標体重を返す。同じ要求の ID の再送は、書かずに初めての応答と同じ形で返す",
      security: [{ session: [] }],
      middleware: [authenticateAccount, rejectUnreadableJsonBody] as const,
      request: {
        body: {
          required: true,
          content: { "application/json": { schema: goalDecisionRequestSchema } },
        },
      },
      responses: {
        200: {
          description: "決めた記録か、決めなかった理由",
          content: { "application/json": { schema: goalDecisionSchema } },
        },
        ...rejectionResponses,
      },
    }),
    async (c) => {
      const decided = await getAccountDurableObject(c.env, c.var.accountId).decideGoal(
        c.var.accountId,
        toGoalDecisionRequest(c.req.valid("json")),
      );
      if (R.isFailure(decided)) {
        return respondGoalSetupRejected(c, decided.error);
      }
      return c.json(toGoalDecisionResponse(decided.value), 200);
    },
  );
