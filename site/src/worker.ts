import { Hono } from "hono";
import { securityHeaders } from "./security-headers";

// assets.run_worker_first（wrangler.jsonc）で、/ と /_lp/* だけがここを通る。ほかのパスは静的な asset のまま返る
const app = new Hono<{ Bindings: Env }>();

// Worker が作る応答には _headers が効かないので、同じ定義から付ける。/ の中身は Cookie の版で変わるので、共有のキャッシュに置かせない
app.use(async (c, next) => {
  await next();
  for (const [name, value] of Object.entries(securityHeaders)) {
    c.res.headers.set(name, value);
  }
  c.res.headers.set("Cache-Control", "private, no-store");
  c.res.headers.set("Vary", "Cookie");
});

// 版の中身は / で返すので、版のパスを別のページとして検索に載せない
app.get("/_lp/*", (c) => c.redirect("/", 301));

app.get("/", async (c) => {
  const variants: readonly string[] = c.env.LP_VARIANTS;
  if (variants.length > 0) {
    throw new Error("LP の版の振り分けはまだ無い（#659）");
  }
  const asset = await c.env.ASSETS.fetch(new URL("/_lp/_placeholder/", c.req.url));
  // asset の応答のヘッダーは書き換えられないので、作り直す
  return new Response(asset.body, asset);
});

export default app;
