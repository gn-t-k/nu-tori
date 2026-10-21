import { Hono } from "hono";
import { createAuthentication } from "../../auth/create-authentication";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { checkE2eAccess } from "./check-e2e-access";
import { e2eRequestHeaders } from "./e2e-request-headers";

// 開発用の環境で主な流れを確かめるジョブ（.github/workflows/deploy.yml）のための、Apple を通さないサインインの口。
// 開くかは checkE2eAccess が決め、開かないときは口が無いのと同じ 404 に、秘密の値が違えば 401 にする。
// OpenAPI の文書に載せない（アプリのクライアントに入れない）ので、スキーマ付きの経路にしない
export const e2eSessionRoutes = new Hono<{ Bindings: Env }>().post(
  "/v1/e2e/sessions",
  async (c) => {
    const access = await checkE2eAccess(c.env, c.req.header(e2eRequestHeaders.signInSecret));
    if (access === "closed") {
      return c.notFound();
    }
    if (access === "unauthorized") {
      return c.body(null, 401);
    }
    const { internalAdapter } = await createAuthentication(c.env, c.req.url).$context;
    const user = await internalAdapter.createUser(
      // oxlint-disable-next-line nu-tori/no-random-uuid -- 仮のメールの名前で、ID として比べない
      { name: "", email: `${crypto.randomUUID()}@nu-tori.invalid`, emailVerified: false },
      // 入口の検査（validateUserInfo）は設定していないが、引数としては要る
      { method: "e2e" },
    );
    const session = await internalAdapter.createSession(user.id);
    await getAccountDurableObject(c.env, user.id).recordFirstSignIn(user.id, {
      signedInAt: new Date(),
      timeZone: undefined,
      // Apple を通さないので、前に無料体験を使った Apple ID には当たらない
      isFreeTrialUsedByEarlierAccount: false,
    });
    return c.json({ sessionToken: session.token, accountId: user.id }, 201);
  },
);
