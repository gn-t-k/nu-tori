import { Hono } from "hono";

// 開発用の環境にデプロイしないと分からないことを確かめる経路（「デプロイと開発用の環境で確かめる」）。確かめ終えたら消す
export const verificationRoutes = new Hono<{ Bindings: Env }>();

verificationRoutes.use(async (c, next) => {
  if (c.env.ENVIRONMENT !== "development") {
    return c.notFound();
  }
  return next();
});

verificationRoutes.get("/server-sent-events", async (c) => {
  const stream = await verificationAccount(c.env).streamServerSentEventsForVerification();
  return new Response(stream, {
    headers: { "content-type": "text/event-stream", "cache-control": "no-cache" },
  });
});

verificationRoutes.post("/deletion/write", async (c) =>
  c.json(await verificationAccount(c.env).writeForVerification()),
);

verificationRoutes.post("/deletion/delete-all", async (c) =>
  c.json(await verificationAccount(c.env).deleteAllForVerification()),
);

verificationRoutes.post("/deletion/restore", async (c) => {
  const { bookmark } = await c.req.json<{ bookmark: string }>();
  // 戻す側は Durable Object を止めるので、呼び出しは必ず失敗する。次の呼び出しで戻った中身を読む
  const restoreError = await verificationAccount(c.env)
    .restoreForVerification(bookmark)
    .then(() => undefined)
    .catch((error: unknown) => String(error));
  return c.json({ restoreError, ...(await verificationAccount(c.env).readForVerification()) });
});

verificationRoutes.post("/workers-ai", async (c) => {
  const { text } = await c.req.json<{ text: string }>();
  return c.json(await verificationAccount(c.env).classifyForVerification(text));
});

const verificationAccount = (env: Env) =>
  env.ACCOUNT.get(env.ACCOUNT.idFromName("verification"), { locationHint: "apac-ne" });
