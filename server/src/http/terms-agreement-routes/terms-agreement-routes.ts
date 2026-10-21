import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import { recordIdSchema } from "../../domain/record-id";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { authenticateAccount } from "../authenticate-account";

// 規約への同意。どれも同期の外の要求で、同期の記録は変えない
export const termsAgreementRoutes = new OpenAPIHono<{ Bindings: Env }>()
  .openapi(
    createRoute({
      method: "get",
      path: "/v1/terms-agreement",
      operationId: "getTermsAgreementRequirement",
      summary: "規約の同意が要るか",
      description:
        "同意を取り直す版より後の版のどれにも同意していなければ、同意が要る。端末は、開いたとき（前面に来たとき）に問い、要れば同意のシートを出す",
      security: [{ session: [] }],
      middleware: [authenticateAccount] as const,
      responses: {
        200: {
          description: "同意が要るかと、同意を求める版",
          content: {
            "application/json": {
              schema: z
                .object({
                  agreementRequired: z.boolean(),
                  termsVersion: z.string().openapi({
                    description: "今の規約の版。同意が要るとき、同意する要求でこの版を送る",
                    example: "1",
                  }),
                })
                .openapi("TermsAgreementRequirement"),
            },
          },
        },
        401: { description: "セッションが無いか、切れている" },
        429: { description: "回数の歯止めにかかった" },
      },
    }),
    async (c) => {
      const requirement = await getAccountDurableObject(
        c.env,
        c.var.accountId,
      ).findTermsAgreementRequirement(c.var.accountId);
      return c.json(requirement, 200);
    },
  )
  .openapi(
    createRoute({
      method: "post",
      path: "/v1/terms-agreements",
      operationId: "agreeToTerms",
      summary: "規約に同意する",
      description:
        "同意のシートでの同意。送り待ちの箱を通さず、その場で送る。同じ要求の ID の再送は、書かずに受け付ける",
      security: [{ session: [] }],
      middleware: [authenticateAccount] as const,
      request: {
        body: {
          required: true,
          content: {
            "application/json": {
              schema: z.object({
                requestId: recordIdSchema.openapi({
                  description: "端末が振った要求の ID（UUID v4）。同意の ID にし、冪等の鍵にする",
                }),
                termsVersion: z.string().openapi({
                  description: "同意のシートで見せた規約の版（同意が要るかの答えの termsVersion）",
                  example: "1",
                }),
              }),
            },
          },
        },
      },
      responses: {
        204: { description: "同意を受け付けた" },
        400: { description: "要求の形が違う" },
        401: { description: "セッションが無いか、切れている" },
        422: {
          description: "知らない規約の版。不具合のときだけ起きる",
          content: {
            "application/json": {
              schema: z
                .object({ code: z.literal("terms_version_unknown") })
                .openapi("TermsAgreementRejection"),
            },
          },
        },
        429: { description: "回数の歯止めにかかった" },
      },
    }),
    async (c) => {
      const agreed = await getAccountDurableObject(c.env, c.var.accountId).agreeToTerms(
        c.var.accountId,
        c.req.valid("json"),
      );
      if (R.isFailure(agreed)) {
        return match(agreed.error)
          .with({ name: "TermsVersionUnknownError" }, () =>
            c.json({ code: "terms_version_unknown" as const }, 422),
          )
          .exhaustive();
      }
      return c.body(null, 204);
    },
  );
