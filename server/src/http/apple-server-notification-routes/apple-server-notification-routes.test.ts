import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId } from "../../domain/record-id";
import { createAuthentication } from "../../auth/create-authentication";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockRevokeAppleRefreshTokenOk } from "../../auth/revoke-apple-refresh-token/revoke-apple-refresh-token.mock";
import { mockAppleKeysEndpointOk, signAppleServerNotification } from "../../auth/testing";
import { app } from "../app";
import { signInTestAccount } from "../testing";

describe("Apple のサーバー間通知", () => {
  describe("アプリへの同意が取り消されたとき", () => {
    let appleUserId: string;
    let signedIn: { accountId: string; sessionToken: string };
    let payload: string;
    beforeEach(async () => {
      appleUserId = generateRecordId();
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      signedIn = await signInTestAccount(appleUserId);
      payload = await signAppleServerNotification({ appleUserId, type: "consent-revoked" });
    });

    test("セッションを取り消すこと", async () => {
      await postNotification(payload);
      const session = await createAuthentication(env, "http://localhost").api.getSession({
        headers: new Headers({ authorization: `Bearer ${signedIn.sessionToken}` }),
      });
      expect(session).toBeNull();
    });

    describe("そのあと同じ Apple ID でサインインし直したとき", () => {
      beforeEach(async () => {
        await postNotification(payload);
      });

      test("同じアカウントに戻ること", async () => {
        const signedInAgain = await signInTestAccount(appleUserId);
        expect(signedInAgain.accountId).toBe(signedIn.accountId);
      });
    });
  });

  describe("Apple アカウントが削除されたとき", () => {
    let accountId: string;
    let revokeSpy: ReturnType<typeof mockRevokeAppleRefreshTokenOk>;
    let payload: string;
    beforeEach(async () => {
      const appleUserId = generateRecordId();
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk({ refreshToken: "apple-refresh-token" });
      revokeSpy = mockRevokeAppleRefreshTokenOk();
      ({ accountId } = await signInTestAccount(appleUserId));
      payload = await signAppleServerNotification({ appleUserId, type: "account-deleted" });
    });

    test("アカウントの削除と同じく、Apple の refresh token を取り消してアカウントを消すこと", async () => {
      await postNotification(payload);
      const user = await env.DB.prepare(`SELECT "id" FROM "user" WHERE "id" = ?`)
        .bind(accountId)
        .first();
      expect({ revoked: revokeSpy.mock.calls.length, user }).toEqual({ revoked: 1, user: null });
    });
  });

  describe("署名が合わないとき", () => {
    let payload: string;
    beforeEach(async () => {
      mockAppleKeysEndpointOk();
      const [header, body] = (
        await signAppleServerNotification({
          appleUserId: generateRecordId(),
          type: "account-deleted",
        })
      ).split(".");
      const [, , otherSignature] = (
        await signAppleServerNotification({
          appleUserId: generateRecordId(),
          type: "account-deleted",
        })
      ).split(".");
      payload = [header, body, otherSignature].join(".");
    });

    test("400 を返すこと", async () => {
      const response = await postNotification(payload);
      expect(response.status).toBe(400);
    });
  });
});

const postNotification = (payload: string) =>
  app.request(
    "/v1/apple-server-notifications",
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ payload }),
    },
    env,
  );
