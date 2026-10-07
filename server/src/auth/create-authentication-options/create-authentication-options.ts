import type { BetterAuthOptions } from "better-auth";
import { bearer } from "better-auth/plugins";
import { generateRecordId } from "../../domain/record-id";

// Better Auth の設定は、createAuthentication と、表が Better Auth の求める形かを確かめるテストが、ここから作る
// Better Auth の HTTP の口は出さず、受け口から api を呼ぶ。baseURL は、無いと作るたびに警告が出るので渡す
export const createAuthenticationOptions = (env: Env, requestUrl: string) =>
  ({
    baseURL: new URL(requestUrl).origin,
    database: env.DB,
    secret: env.BETTER_AUTH_SECRET,
    socialProviders: {
      apple: {
        clientId: env.APPLE_BUNDLE_ID,
        // ネイティブの ID トークンの流れでは使わない。認可コードの交換は exchangeAppleAuthorizationCode で行う
        clientSecret: "",
        appBundleIdentifier: env.APPLE_BUNDLE_ID,
        // Better Auth はメールを必須にするので、Apple のメールの代わりに sub と関係ない仮の値を入れる
        mapProfileToUser: () => ({
          name: "",
          // oxlint-disable-next-line nu-tori/no-random-uuid -- 仮のメールの名前で、ID として比べない
          email: `${crypto.randomUUID()}@nu-tori.invalid`,
          emailVerified: false,
        }),
      },
    },
    session: {
      expiresIn: 60 * 60 * 24 * 180,
      updateAge: 60 * 60 * 24,
    },
    databaseHooks: {
      account: {
        // Apple の ID トークンはメールを含むので、Better Auth がアカウントの行に入れる前に外す
        create: { before: async (account) => ({ data: { ...account, idToken: null } }) },
        update: { before: async (account) => ({ data: { ...account, idToken: null } }) },
      },
    },
    advanced: {
      database: {
        generateId: () => generateRecordId(),
        // 表の正本は d1-migrations/ で、テストが表を使って確かめる。確かめると、アイソレートが起動するたびに D1 を問い合わせる
        validateSchema: false,
      },
    },
    plugins: [bearer()],
  }) satisfies BetterAuthOptions;
