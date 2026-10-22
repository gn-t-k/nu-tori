import { Hono } from "hono";
import { generateCookie, getCookie } from "hono/cookie";
import { isLandingVariantName } from "./is-landing-variant-name";
import { securityHeaders } from "./security-headers";

// 振り分けの Worker。本番（worker.ts）は版を Math.random で選び、テスト（testing/landing-variants-test-worker.ts）は決めた値で選ぶ。
// Worker の中の Math.random は vi.spyOn で差し替えられず、Worker の変数で差し替えると本番の vars に誤って入れたときに振り分けが偏るため、束ねる入口で渡す
export const createSiteWorker = (drawVariant: () => number) => {
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
    if (variants.length === 0) {
      return fetchPage(c.env, c.req.url, "/_lp/_placeholder/");
    }
    // 設定の誤りは振り分ける前に止める
    if (!variants.every(isLandingVariantName)) {
      throw new Error(`LP_VARIANTS の版の名前は英小文字と数字だけにする: ${variants.join(", ")}`);
    }

    const variantCookieName = "nu_tori_lp";
    // 外した版と壊れた値は、一覧に無いので選び直す
    const remembered = getCookie(c, variantCookieName);
    if (remembered !== undefined && variants.includes(remembered)) {
      return fetchPage(c.env, c.req.url, `/_lp/${remembered}/`);
    }

    const draw = drawVariant();
    const chosen = variants[Math.floor(draw * variants.length)];
    if (chosen === undefined) {
      throw new Error(`版を選ぶ乱数が 0 以上 1 未満でない: ${draw}`);
    }
    const page = await fetchPage(c.env, c.req.url, `/_lp/${chosen}/`);
    // 版の名前のほかは入れず、訪問者を見分ける値を作らない
    page.headers.append(
      "Set-Cookie",
      generateCookie(variantCookieName, chosen, {
        path: "/",
        maxAge: 2_592_000,
        secure: true,
        httpOnly: true,
        sameSite: "Lax",
      }),
    );
    return page;
  });

  return app;
};

const fetchPage = async (env: Env, requestUrl: string, path: string): Promise<Response> => {
  const asset = await env.ASSETS.fetch(new URL(path, requestUrl));
  // asset の応答のヘッダーは書き換えられないので、作り直す
  return new Response(asset.body, asset);
};
