import { captureException } from "@sentry/cloudflare";
import { sql } from "drizzle-orm";
import { drizzle } from "drizzle-orm/d1";
import { Hono } from "hono";

// 認証なしで呼べるので、本文に記録の中身もアカウントの情報も入れない（ADR-0017）
// アプリのクライアントに入れないので、OpenAPI の文書に載るスキーマ付きの経路にしない
export const healthRoutes = new Hono<{ Bindings: Env }>().get("/health", async (c) => {
  const isD1Readable = await drizzle(c.env.DB)
    .get(sql`select 1`)
    .then(
      () => true,
      (error: unknown) => {
        // 503 を返すために受け止めるので、基盤の障害として Sentry に送っておく
        captureException(error);
        return false;
      },
    );
  return isD1Readable ? c.json({ status: "ok" }, 200) : c.json({ status: "unavailable" }, 503);
});
