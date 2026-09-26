import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import {
  mockRevokeAppleRefreshTokenError,
  mockRevokeAppleRefreshTokenOk,
} from "../../auth/revoke-apple-refresh-token/revoke-apple-refresh-token.mock";
import { RevokeAppleRefreshTokenError } from "../../auth/revoke-apple-refresh-token";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { app } from "../app";
import { signInTestAccount } from "../testing";

describe("アカウントの削除", () => {
  describe("記録のあるアカウントでサインインしているとき", () => {
    let signedIn: { accountId: string; sessionToken: string };
    let revokeSpy: ReturnType<typeof mockRevokeAppleRefreshTokenOk>;
    beforeEach(async () => {
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk({ refreshToken: "apple-refresh-token" });
      revokeSpy = mockRevokeAppleRefreshTokenOk();
      signedIn = await signInTestAccount(crypto.randomUUID());
      await runInDurableObject(getAccountDurableObject(env, signedIn.accountId), (_, state) => {
        state.storage.sql.exec("CREATE TABLE meals (id TEXT PRIMARY KEY)");
      });
    });

    test("Apple の refresh token を取り消すこと", async () => {
      await deleteSignedInAccount(signedIn.sessionToken);
      expect(revokeSpy).toHaveBeenCalledWith(expect.anything(), "apple-refresh-token");
    });

    test("記録を消すこと", async () => {
      await deleteSignedInAccount(signedIn.sessionToken);
      const tables = await runInDurableObject(
        getAccountDurableObject(env, signedIn.accountId),
        (_, state) =>
          state.storage.sql.exec("SELECT name FROM sqlite_master WHERE name = 'meals'").toArray(),
      );
      expect(tables).toEqual([]);
    });

    test("アカウントと Apple の refresh token の行を消すこと", async () => {
      await deleteSignedInAccount(signedIn.sessionToken);
      const rows = await env.DB.prepare(
        `SELECT
           (SELECT COUNT(*) FROM "user" WHERE "id" = ?1) AS users,
           (SELECT COUNT(*) FROM apple_refresh_tokens WHERE account_id = ?1) AS appleRefreshTokens`,
      )
        .bind(signedIn.accountId)
        .first();
      expect(rows).toEqual({ users: 0, appleRefreshTokens: 0 });
    });

    test("消したあとはセッションを受け付けないこと", async () => {
      await deleteSignedInAccount(signedIn.sessionToken);
      const response = await deleteSignedInAccount(signedIn.sessionToken);
      expect(response.status).toBe(401);
    });
  });

  describe("Apple の取り消しに一度失敗したとき", () => {
    let sessionToken: string;
    beforeEach(async () => {
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      ({ sessionToken } = await signInTestAccount(crypto.randomUUID()));
      mockRevokeAppleRefreshTokenError(new RevokeAppleRefreshTokenError(503));
      await deleteSignedInAccount(sessionToken);
      mockRevokeAppleRefreshTokenOk();
    });

    test("同じセッションでやり直せること", async () => {
      const response = await deleteSignedInAccount(sessionToken);
      expect(response.status).toBe(204);
    });
  });
});

const deleteSignedInAccount = (sessionToken: string) =>
  app.request(
    "/v1/account",
    { method: "DELETE", headers: { authorization: `Bearer ${sessionToken}` } },
    env,
  );
