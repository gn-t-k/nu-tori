import { Hono } from "hono";
import { recordIdSchema } from "../../domain/record-id";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { authenticateAccount } from "../authenticate-account";
import { requireE2eAccess } from "../e2e-access";

// 開発用の環境で主な流れを確かめるジョブが、食事の推定が「推定できなかった」で終わった理由を知らせるための口。
// 同期の推定の状態は理由を持たないので、最後に終わった試みの結果と提供元のエラーの種類を返す。
// 食事はアカウントの Durable Object にあるので、秘密の値に加えてセッションでアカウントを決める。
// OpenAPI の文書に載せない（アプリのクライアントに入れない）ので、スキーマ付きの経路にしない
export const e2eEstimationAttemptRoutes = new Hono<{ Bindings: Env }>().get(
  "/v1/e2e/meals/:mealId/last-estimation-attempt",
  requireE2eAccess,
  authenticateAccount,
  async (c) => {
    const mealId = recordIdSchema.safeParse(c.req.param("mealId"));
    if (!mealId.success) {
      return c.body(null, 400);
    }
    const conclusion = await getAccountDurableObject(
      c.env,
      c.var.accountId,
    ).findLastEstimationAttemptConclusionOfMeal(c.var.accountId, mealId.data);
    return c.json({
      lastEndedAttempt:
        conclusion === undefined
          ? null
          : {
              result: conclusion.result,
              errorType: "errorType" in conclusion ? conclusion.errorType : null,
            },
    });
  },
);
