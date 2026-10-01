import { Hono } from "hono";
import { createAuthentication } from "../../auth/create-authentication";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";

const minimumSecretLength = 32;

// 開発用の環境で主な流れを確かめるジョブ（.github/workflows/deploy.yml）のための、Apple を通さないサインインの口。
// 開いてはいけない環境（本番）で開くと誰でも入れてしまうので、次のすべてが揃ったときだけ開き、ほかは口が無いのと同じ 404 にする。
// 1. 環境の名前（SENTRY_ENVIRONMENT）が development。許可する名前を挙げ、本番や綴りの違う名前は閉じる
// 2. 秘密の値（E2E_SIGN_IN_SECRET）が置かれていて、推測されにくい長さがある。本番には置かない
// 3. 要求が同じ秘密の値を送っている
// OpenAPI の文書に載せない（アプリのクライアントに入れない）ので、スキーマ付きの経路にしない
export const e2eSessionRoutes = new Hono<{ Bindings: Env }>().post(
  "/v1/e2e/sessions",
  async (c) => {
    const secret = c.env.E2E_SIGN_IN_SECRET;
    if (
      c.env.SENTRY_ENVIRONMENT !== "development" ||
      secret === undefined ||
      secret.length < minimumSecretLength
    ) {
      return c.notFound();
    }
    if (!(await isSameSecret(secret, c.req.header("x-e2e-sign-in-secret") ?? ""))) {
      return c.body(null, 401);
    }
    const { internalAdapter } = await createAuthentication(c.env, c.req.url).$context;
    const user = await internalAdapter.createUser(
      { name: "", email: `${crypto.randomUUID()}@nu-tori.invalid`, emailVerified: false },
      // 入口の検査（validateUserInfo）は設定していないが、引数としては要る
      { method: "e2e" },
    );
    const session = await internalAdapter.createSession(user.id);
    await getAccountDurableObject(c.env, user.id).recordFirstSignIn(user.id, {
      signedInAt: new Date(),
      timeZone: undefined,
    });
    return c.json({ sessionToken: session.token, accountId: user.id }, 201);
  },
);

// 長さを漏らさず、一致までの時間が内容によらないよう、ハッシュにしてから比べる
const isSameSecret = async (expected: string, sent: string): Promise<boolean> => {
  const [expectedDigest, sentDigest] = await Promise.all([sha256(expected), sha256(sent)]);
  return crypto.subtle.timingSafeEqual(expectedDigest, sentDigest);
};

const sha256 = (value: string): Promise<ArrayBuffer> =>
  crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
