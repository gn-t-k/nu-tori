import { captureException } from "@sentry/cloudflare";
import { sql } from "drizzle-orm";
import { drizzle } from "drizzle-orm/d1";
import { Hono } from "hono";

// 本番のデプロイの前に、開発用に出した Worker が応答し、D1 を読めるかだけを確かめる経路（.github/workflows/deploy.yml の shallow-check）。
// 主な流れを通す確かめ（verify-development）とは別のもの。
// 認証なしで呼べるので、本文は決まった形だけにし、記録の中身もアカウントの情報も入れない（ADR-0017）。
// アプリの API の版（/v1）の外に置き、強制アップデートの判定にかけない。
// OpenAPI の文書に載せない（アプリのクライアントに入れない）ので、スキーマ付きの経路にしない
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
