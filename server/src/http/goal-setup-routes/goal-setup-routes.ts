import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { R } from "@praha/byethrow";
import { ErrorFactory } from "@praha/error-factory";
import { captureException } from "@sentry/cloudflare";
import { match } from "ts-pattern";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { authenticateAccount } from "../authenticate-account";
import { dailyGuidePlanSchema, toDailyGuidePlan } from "./daily-guide-plan-schema";
import { goalProposalsSchema, toGoalProposalsResponse } from "./goal-proposals-schema";
import {
  calendarDaySchema,
  goalSetupSituationSchema,
  toGoalSetupSituation,
} from "./goal-setup-situation-schema";

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

const weightChangeDirectionSchema = z.enum(["lose", "gain"]);

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
      middleware: [authenticateAccount] as const,
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
        captureException(previewed.error);
        return c.json({ code: previewed.error.reason }, 422);
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
      middleware: [authenticateAccount] as const,
      request: {
        body: {
          required: true,
          content: {
            "application/json": {
              schema: goalSetupSituationSchema
                .extend({
                  direction: z.enum(["lose", "gain", "maintain"]),
                  deadlineOn: calendarDaySchema.optional().openapi({
                    description:
                      "期限。減量・増量では必ず付ける。開始の日から数えて（両端を含む）28〜182 日の日",
                  }),
                })
                .superRefine(({ direction, deadlineOn }, context) => {
                  if (direction !== "maintain" && deadlineOn === undefined) {
                    context.addIssue({
                      code: "custom",
                      path: ["deadlineOn"],
                      message: "減量・増量には期限が要る",
                    });
                  }
                }),
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
      const { direction, deadlineOn, ...situation } = c.req.valid("json");
      const proposed = await getAccountDurableObject(c.env, c.var.accountId).proposeGoals(
        c.var.accountId,
        {
          ...toGoalSetupSituation(situation),
          // 減量・増量で期限が無い要求は、スキーマが形の誤りとして断っている
          plan:
            direction === "maintain" || deadlineOn === undefined
              ? { direction: "maintain" }
              : { direction, deadlineOn },
        },
      );
      if (R.isFailure(proposed)) {
        captureException(proposed.error);
        return c.json({ code: proposed.error.reason }, 422);
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
      middleware: [authenticateAccount] as const,
      request: {
        body: {
          required: true,
          content: {
            "application/json": {
              schema: goalSetupSituationSchema.extend({
                direction: weightChangeDirectionSchema,
                deadlineOn: calendarDaySchema,
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
        captureException(assessed.error);
        return c.json({ code: assessed.error.reason }, 422);
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
  );

// 形の誤りで断った要求。値は残さないので、誤っていた場所（キーの道筋）と種類だけを持つ
class GoalSetupRequestMalformedError extends ErrorFactory({
  name: "GoalSetupRequestMalformedError",
  message: "目標の設定の要求の形が違う",
  fields: ErrorFactory.fields<{ issues: { path: string; code: string }[] }>(),
}) {}
