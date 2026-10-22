import { Hono } from "hono";
import { createMiddleware } from "hono/factory";
import { recordIdSchema } from "../../domain/record-id";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { authenticateAccount } from "../authenticate-account";
import { checkE2eAccess } from "../e2e-session-routes/check-e2e-access";
import { e2eRequestHeaders } from "../e2e-session-routes/e2e-request-headers";

// 開発用の環境で主な流れを確かめるジョブが、食事の推定が「推定できなかった」で終わった理由を知らせるための口。
// 同期の推定の状態は理由を持たないので、最後に終わった試みの結果と提供元のエラーの種類を返す。
// 開くかはサインインの口と同じく checkE2eAccess が決め、そのうえでセッションを確かめる。
// OpenAPI の文書に載せない（アプリのクライアントに入れない）ので、スキーマ付きの経路にしない
export const e2eEstimationAttemptRoutes = new Hono<{ Bindings: Env }>().get(
  "/v1/e2e/meals/:mealId/last-estimation-attempt",
  createMiddleware<{ Bindings: Env }>(async (c, next) => {
    const access = await checkE2eAccess(c.env, c.req.header(e2eRequestHeaders.signInSecret));
    if (access === "closed") {
      return c.notFound();
    }
    if (access === "unauthorized") {
      return c.body(null, 401);
    }
    return next();
  }),
  authenticateAccount,
  async (c) => {
    const mealId = recordIdSchema.safeParse(c.req.param("mealId"));
    if (!mealId.success) {
      return c.body(null, 400);
    }
    const attempt = await getAccountDurableObject(
      c.env,
      c.var.accountId,
    ).findLastEndedEstimationAttemptOfMeal(c.var.accountId, mealId.data);
    return c.json({
      lastEndedAttempt:
        attempt === undefined
          ? null
          : {
              result: attempt.result,
              errorType: "errorType" in attempt ? attempt.errorType : null,
            },
    });
  },
);
