import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { createAppleRefreshTokenStore } from "../../auth/create-apple-refresh-token-store";
import { createAuthentication } from "../../auth/create-authentication";
import { AppleAuthorizationCodeRejectedError } from "../../auth/exchange-apple-authorization-code";
import {
  mockExchangeAppleAuthorizationCodeError,
  mockExchangeAppleAuthorizationCodeOk,
} from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk, signAppleIdToken } from "../../auth/testing";
import { app } from "../app";
import { signInTestAccount, signInWithApple } from "../testing";

describe("サインイン", () => {
  describe("ID トークンと認可コードを受け付けたとき", () => {
    let appleUserId: string;
    beforeEach(() => {
      appleUserId = crypto.randomUUID();
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk({ refreshToken: "apple-refresh-token" });
    });

    test("以後の要求に使えるセッションのトークンを返すこと", async () => {
      const response = await signInWithApple(appleUserId);
      const { sessionToken } = await response.json<{ sessionToken: string }>();
      const session = await createAuthentication(env, "http://localhost").api.getSession({
        headers: new Headers({ authorization: `Bearer ${sessionToken}` }),
      });
      expect({ status: response.status, signedIn: session !== null }).toEqual({
        status: 201,
        signedIn: true,
      });
    });

    test("Apple の refresh token を保存すること", async () => {
      const { accountId } = await signInTestAccount(appleUserId);
      const refreshToken = await createAppleRefreshTokenStore(
        env.DB,
        env.APPLE_REFRESH_TOKEN_KEYS,
      ).find(accountId);
      expect(refreshToken).toBe("apple-refresh-token");
    });
  });

  describe("同じ Apple ID でサインインしたことがあるとき", () => {
    let appleUserId: string;
    let accountId: string;
    beforeEach(async () => {
      appleUserId = crypto.randomUUID();
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      ({ accountId } = await signInTestAccount(appleUserId));
    });

    test("同じアカウントに入ること", async () => {
      const signedInAgain = await signInTestAccount(appleUserId);
      expect(signedInAgain.accountId).toBe(accountId);
    });

    test("Apple のメールと ID トークンを保存しないこと", async () => {
      await signInWithApple(appleUserId);
      const saved = await env.DB.prepare(
        `SELECT "user"."email", account."idToken" FROM "user"
         JOIN account ON account."userId" = "user"."id" WHERE "user"."id" = ?`,
      )
        .bind(accountId)
        .first<{ email: string; idToken: string | null }>();
      expect(saved).toEqual({ email: expect.stringMatching(/@nu-tori\.invalid$/), idToken: null });
    });
  });

  describe("ID トークンの nonce が送った nonce と違うとき", () => {
    let body: string;
    beforeEach(async () => {
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      body = JSON.stringify({
        idToken: await signAppleIdToken({ appleUserId: crypto.randomUUID(), nonce: "nonce-1" }),
        nonce: "nonce-2",
        authorizationCode: "authorization-code",
      });
    });

    test("401 を返すこと", async () => {
      const response = await app.request(
        "/v1/sessions",
        { method: "POST", headers: { "content-type": "application/json" }, body },
        env,
      );
      expect(response.status).toBe(401);
    });
  });

  describe("Apple が認可コードを受け付けなかったとき", () => {
    let appleUserId: string;
    beforeEach(() => {
      appleUserId = crypto.randomUUID();
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeError(new AppleAuthorizationCodeRejectedError());
    });

    test("401 を返すこと", async () => {
      const response = await signInWithApple(appleUserId);
      expect(response.status).toBe(401);
    });
  });
});
