import { bodyLimit } from "hono/body-limit";
import { createMiddleware } from "hono/factory";

// 要求の本文の大きさに上限をかけ、超えたら経路を呼ばずに 413 で断る。
// セッションの確かめより前に置く。413 は入口で扱い、経路のスキーマに載せない（写真の口は自分のスキーマに載せている）
export const limitRequestBody = createMiddleware(async (c, next) => {
  // 写真の口は JSON でなく、自分の上限を持つ
  if (c.req.path.startsWith("/v1/meal-photos/")) {
    return next();
  }
  return c.req.path === "/v1/sync/writes" ? limitSyncWrites(c, next) : limitJson(c, next);
});

// 同期の書き込みは1回 500 件まで。いちばん大きい書き込み（500 文字の送った文章）を 500 件並べると、UTF-8 で 4 バイトの文字だけでも 1.1 MB ほど（端末は、ASCII でない文字を \u の形にせずそのまま送る）。
// 今のアプリは 413 を受けると同じ要求を送り続けるので、ふつうの要求が届かない大きさにする
const limitSyncWrites = bodyLimit({
  maxSize: 2 * 1024 * 1024,
  onError: (c) => c.body(null, 413),
});

// ほかの JSON の本文でいちばん大きいのは App Store の署名つきの値（証明書の鎖を含む通知）で、数十 KB に満たない
const limitJson = bodyLimit({ maxSize: 64 * 1024, onError: (c) => c.body(null, 413) });
