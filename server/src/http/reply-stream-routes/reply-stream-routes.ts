import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { recordIdSchema } from "../../domain/record-id";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { authenticateAccount } from "../authenticate-account";
import { replyStreamEventSchema } from "./reply-stream-event-schema";

export const replyStreamRoutes = new OpenAPIHono<{ Bindings: Env }>().openapi(
  createRoute({
    method: "get",
    path: "/v1/sent-texts/{sentTextId}/reply-stream",
    operationId: "watchReply",
    summary: "送った文章の見守る要求",
    description:
      "応答を待つ送った文章があるあいだつなぐ。はじめに返事の ID、続けてできた分を流す。食事と読み分けた・返事を記録に書いた・回数切れ・作れなかったときは、その結果を送って閉じる。つなぐ前にそうなっていれば、結果だけを送って閉じる。端末が切れても、サーバーは返事を最後まで作って記録に書く。届け方の正本は同期で、途中の文は記録に残らない",
    security: [{ session: [] }],
    middleware: [authenticateAccount] as const,
    request: {
      params: z.object({
        sentTextId: recordIdSchema.openapi({
          param: { name: "sentTextId", in: "path" },
          description: "送った文章の ID",
        }),
      }),
    },
    responses: {
      200: {
        description: "出来事ごとに、data に JSON（ReplyStreamEvent）を1つ持つ SSE",
        content: { "text/event-stream": { schema: replyStreamEventSchema } },
      },
      400: { description: "経路の形が違う" },
      401: { description: "セッションが無いか、切れている" },
      404: { description: "まだ受け取っていない送った文章" },
      429: { description: "回数の歯止めにかかった" },
    },
  }),
  async (c) => {
    const stream = await getAccountDurableObject(c.env, c.var.accountId).watchReply(
      c.var.accountId,
      c.req.valid("param").sentTextId,
    );
    if (stream === undefined) {
      return c.body(null, 404);
    }
    return c.body(stream, 200, {
      "content-type": "text/event-stream",
      "cache-control": "no-cache",
    });
  },
);
