import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { bodyLimit } from "hono/body-limit";
import { createMiddleware } from "hono/factory";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { authenticateAccount } from "../authenticate-account";

// 縮小版（長辺 1024px）の JPEG は 1 MB に満たない。LLM の提供元に base64 で送ると 4/3 倍になり、提供元の上限（5 MB）を超えないようにする
const maximumPhotoBytes = 3 * 1024 * 1024;
const photoContentType = "image/jpeg";

const photoIdParams = z.object({
  photoId: z
    .string()
    .min(1)
    .openapi({ param: { name: "photoId", in: "path" }, description: "端末が振った写真の ID" }),
});

// bodyLimit の型は Variables を何でも許す形なので、包んで accountId の型を保つ
const limitPhotoSize = createMiddleware<{ Bindings: Env }>(
  bodyLimit({ maxSize: maximumPhotoBytes, onError: (c) => c.body(null, 413) }),
);

export const mealPhotoRoutes = new OpenAPIHono<{ Bindings: Env }>()
  .openapi(
    createRoute({
      method: "put",
      path: "/v1/meal-photos/{photoId}",
      operationId: "putMealPhoto",
      summary: "食事の写真の縮小版を送る",
      description:
        "食事の書き込みとは別に送る。食事より先に届いてもよい。同じ写真が再び届いたときと、消した食事の写真が届いたときも、受け取った形で応える",
      security: [{ session: [] }],
      middleware: [authenticateAccount, limitPhotoSize] as const,
      request: {
        params: photoIdParams,
        body: {
          required: true,
          content: {
            [photoContentType]: {
              schema: z.string().openapi({ format: "binary", description: "EXIF の無い JPEG" }),
            },
          },
        },
      },
      responses: {
        204: { description: "受け取った" },
        400: { description: "経路の形が違う" },
        401: { description: "セッションが無いか、切れている" },
        413: { description: "3 MiB を超えている" },
        415: { description: "JPEG でない" },
        429: { description: "回数の歯止めにかかった" },
        500: { description: "受け取れなかった。送り直す" },
      },
    }),
    async (c) => {
      const mediaType = c.req.header("content-type")?.split(";")[0]?.trim().toLowerCase();
      if (mediaType !== photoContentType) {
        return c.body(null, 415);
      }
      await getAccountDurableObject(c.env, c.var.accountId).receiveMealPhoto(c.var.accountId, {
        photoId: c.req.valid("param").photoId,
        photo: await c.req.arrayBuffer(),
      });
      return c.body(null, 204);
    },
  )
  .openapi(
    createRoute({
      method: "get",
      path: "/v1/meal-photos/{photoId}",
      operationId: "getMealPhoto",
      summary: "食事の写真の縮小版を取りに行く",
      security: [{ session: [] }],
      middleware: [authenticateAccount] as const,
      request: { params: photoIdParams },
      responses: {
        200: {
          description: "受け取っていて、消していない写真",
          content: { [photoContentType]: { schema: z.string().openapi({ format: "binary" }) } },
        },
        401: { description: "セッションが無いか、切れている" },
        404: { description: "まだ受け取っていないか、消した" },
        429: { description: "回数の歯止めにかかった" },
      },
    }),
    async (c) => {
      const photo = await getAccountDurableObject(c.env, c.var.accountId).readMealPhoto(
        c.var.accountId,
        c.req.valid("param").photoId,
      );
      if (photo === undefined) {
        return c.body(null, 404);
      }
      return c.body(photo, 200, { "content-type": photoContentType });
    },
  );
