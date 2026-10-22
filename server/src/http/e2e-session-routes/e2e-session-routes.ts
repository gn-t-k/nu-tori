import { Hono } from "hono";
import { createAuthentication } from "../../auth/create-authentication";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { requireE2eAccess, resolveRequestedAt } from "../e2e-access";

// 開発用の環境で主な流れを確かめるジョブ（.github/workflows/deploy.yml）のための、Apple を通さないサインインの口。
// 時刻の差し替え（resolve-requested-at.ts）を送ると、その時刻にサインインしたことにする。確かめのジョブが、無料体験の終わったアカウントを作るため。
// OpenAPI の文書に載せない（アプリのクライアントに入れない）ので、スキーマ付きの経路にしない
export const e2eSessionRoutes = new Hono<{ Bindings: Env }>().post(
  "/v1/e2e/sessions",
  requireE2eAccess,
  async (c) => {
    const { internalAdapter } = await createAuthentication(c.env, c.req.url).$context;
    const user = await internalAdapter.createUser(
      // oxlint-disable-next-line nu-tori/no-random-uuid -- 仮のメールの名前で、ID として比べない
      { name: "", email: `${crypto.randomUUID()}@nu-tori.invalid`, emailVerified: false },
      // 入口の検査（validateUserInfo）は設定していないが、引数としては要る
      { method: "e2e" },
    );
    const session = await internalAdapter.createSession(user.id);
    await getAccountDurableObject(c.env, user.id).recordFirstSignIn(user.id, {
      signedInAt: await resolveRequestedAt(c.env, (name) => c.req.header(name)),
      timeZone: undefined,
      // Apple を通さないので、前に無料体験を使った Apple ID には当たらない
      isFreeTrialUsedByEarlierAccount: false,
      agreedTermsVersion: undefined,
    });
    return c.json({ sessionToken: session.token, accountId: user.id }, 201);
  },
);
