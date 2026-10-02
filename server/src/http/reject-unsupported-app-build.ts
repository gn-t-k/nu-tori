import { createMiddleware } from "hono/factory";

// アプリから来ない経路。Apple はビルド番号を送らない
const excludedPaths = new Set(["/v1/apple-server-notifications"]);

// 最低バージョンより古いアプリの要求を、経路を呼ばずに 426 で締め出す。
// セッションの確かめと回数の歯止めより前に置き、サインインの要求も締め出す。
// X-App-Build と 426 は入口で扱い、経路のスキーマに載せない
export const rejectUnsupportedAppBuild = createMiddleware<{
  Bindings: { MINIMUM_APP_BUILD?: number };
  Variables: { unsupportedAppBuild?: number };
}>(async (c, next) => {
  const minimumAppBuild = c.env.MINIMUM_APP_BUILD;
  const appBuild = parseAppBuild(c.req.header("x-app-build"));
  // 最低バージョンを持たない環境（開発用）では判定しない
  if (
    minimumAppBuild !== undefined &&
    !excludedPaths.has(c.req.path) &&
    appBuild < minimumAppBuild
  ) {
    c.set("unsupportedAppBuild", appBuild);
    return c.json({ code: "app_build_unsupported" }, 426);
  }
  return next();
});

// ヘッダーが無いか、整数として読めないときは 0。ヘッダーを送る前の版を、最低バージョンを 1 以上にして締め出せる
const parseAppBuild = (header: string | undefined): number =>
  header !== undefined && /^[0-9]+$/.test(header) ? Number(header) : 0;
